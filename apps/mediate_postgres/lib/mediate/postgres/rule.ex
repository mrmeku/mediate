defmodule Mediate.Postgres.Rule do
  @moduledoc """
  One rule as `pg_policy` holds it: the name, the table, the command it
  applies to, and the `USING` and `WITH CHECK` expressions as the database
  renders them. A rule is one line of the policy, and the policy is every
  rule on the bound tables.

  Two names are the engine's business, and the migration helpers write
  both. `mediate_filter_<action>` is a `SELECT` rule that narrows the rows
  of that action. The helper guards it on
  `current_setting('mediate.action', true)`, so two actions on one table
  never widen each other. `mediate_gate_<action>` is an `UPDATE` rule.
  `authorize` reads its `USING` expression before a write, and the
  database applies its `WITH CHECK` expression to the write itself. A rule
  under any other name belongs to whoever wrote it, and `kind/1` answers
  `:other` for it.
  """

  alias Mediate.Postgres.Domain.Identifier

  @filter "mediate_filter_"
  @gate "mediate_gate_"
  @identifier ~r/\A[a-z_][a-z0-9_]*\z/
  @commands ~w(all select insert update delete)

  @enforce_keys [:name, :table, :command, :using, :with_check]
  defstruct @enforce_keys

  @typedoc "The command a rule applies to, as `polcmd` spells it."
  @type command :: :all | :select | :insert | :update | :delete

  @typedoc "One rule as `pg_policy` holds it."
  @type t :: %__MODULE__{
          name: String.t(),
          table: String.t(),
          command: command(),
          using: String.t() | nil,
          with_check: String.t() | nil
        }

  @doc "The name of the filter rule of an action."
  @spec filter_name(String.t()) :: String.t()
  def filter_name(action) when is_binary(action), do: @filter <> action

  @doc "The name of the gate rule of an action."
  @spec gate_name(String.t()) :: String.t()
  def gate_name(action) when is_binary(action), do: @gate <> action

  @doc "What the rule is to the engine: the filter of an action, its gate, or none of its business."
  @spec kind(t()) :: {:filter, String.t()} | {:gate, String.t()} | :other
  def kind(%__MODULE__{name: name}) do
    cond do
      action = after_prefix(name, @filter) -> {:filter, action}
      action = after_prefix(name, @gate) -> {:gate, action}
      true -> :other
    end
  end

  @doc "The command letter `polcmd` carries, as an atom."
  @spec command(String.t()) :: command()
  def command("*"), do: :all
  def command("r"), do: :select
  def command("a"), do: :insert
  def command("w"), do: :update
  def command("d"), do: :delete

  @doc "The rule as the text a release carries."
  @spec to_text(t()) :: String.t()
  def to_text(%__MODULE__{} = rule) do
    "#{rule.table} #{rule.name} #{rule.command}\n" <>
      "  USING #{rule.using || "-"}\n  WITH CHECK #{rule.with_check || "-"}\n"
  end

  @doc """
  The rules a release's text carries, back as structs. An expression the
  database renders runs over several lines. So the line that begins a rule
  holds a table, a name, and a command, and nothing else. Every other line
  belongs to the expression above it.
  """
  @spec from_text(String.t()) :: [t()]
  def from_text(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.reduce([], &read/2)
    |> Enum.reverse()
    |> Enum.map(&close/1)
  end

  @doc """
  The statement that writes the rule. The text carries no role list,
  because the helpers write none. A rule of this package applies to every
  role and names the role it admits inside its expression.
  """
  @spec to_sql(t()) :: String.t()
  def to_sql(%__MODULE__{} = rule) do
    "CREATE POLICY #{Identifier.check!(rule.name, :policy)} ON #{Identifier.check!(rule.table, :table)} " <>
      "FOR #{sql_command(rule.command)}" <> clause(" USING", rule.using) <> clause(" WITH CHECK", rule.with_check)
  end

  defp sql_command(:all), do: "ALL"
  defp sql_command(:select), do: "SELECT"
  defp sql_command(:insert), do: "INSERT"
  defp sql_command(:update), do: "UPDATE"
  defp sql_command(:delete), do: "DELETE"

  defp clause(_keyword, nil), do: ""
  defp clause(keyword, expression), do: "#{keyword} (#{expression})"

  defp read(line, read_so_far) do
    case parse(line) do
      {:header, rule} -> [{rule, nil} | read_so_far]
      {:expression, field, first} -> [open(hd(read_so_far), field, first) | tl(read_so_far)]
      :continuation -> [continue(hd(read_so_far), line) | tl(read_so_far)]
      :blank -> read_so_far
    end
  end

  defp parse(line) do
    cond do
      line == "" -> :blank
      header = header(line) -> {:header, header}
      expression = expression(line, "  USING ", :using) -> expression
      expression = expression(line, "  WITH CHECK ", :with_check) -> expression
      true -> :continuation
    end
  end

  defp header(line) do
    with [table, name, command] <- String.split(line, " "),
         true <- Regex.match?(@identifier, table),
         true <- Regex.match?(@identifier, name),
         true <- command in @commands do
      %__MODULE__{
        name: name,
        table: table,
        command: String.to_existing_atom(command),
        using: nil,
        with_check: nil
      }
    else
      _other -> nil
    end
  end

  defp expression(line, keyword, field) do
    case String.split(line, keyword, parts: 2) do
      ["", rest] -> {:expression, field, rest}
      _other -> nil
    end
  end

  defp open({%__MODULE__{} = rule, _field}, field, first), do: {Map.put(rule, field, first), field}

  defp continue({%__MODULE__{} = rule, field}, line) do
    {Map.put(rule, field, Map.fetch!(rule, field) <> "\n" <> line), field}
  end

  defp close({%__MODULE__{} = rule, _field}) do
    %{rule | using: value(rule.using), with_check: value(rule.with_check)}
  end

  defp value("-"), do: nil
  defp value(other), do: other

  defp after_prefix(name, prefix) do
    case String.replace_prefix(name, prefix, "") do
      ^name -> nil
      "" -> nil
      rest -> rest
    end
  end
end
