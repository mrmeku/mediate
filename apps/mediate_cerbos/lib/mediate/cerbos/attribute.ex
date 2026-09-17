defmodule Mediate.Cerbos.Attribute do
  @moduledoc """
  One attribute declaration: the name the policies know it by, and where its
  value comes from.

  Two sources. `column:` names a column of the kind's schema. The value is
  what the row holds.

  `subquery:` names a function of the subject and the environment. The
  function returns a query that selects `%{id: ..., value: ...}`, with the
  value as text, because a policy compares text. So the value can depend on
  who asks, and on the moment the port stamped the request with. The `id`
  is the row the value belongs to. A row with several values gets the list
  of them. A subject's own subquery attribute gets the list of its values,
  because its id is the only one asked about.

  No declaration can take the name `environment`. It is the principal
  attribute the request-time facts travel under. A declaration of that name
  puts a row's value where the moment of the request goes, so `new/2`
  refuses it.

  The two sources differ in what a query plan compiles to. A column becomes
  a comparison on the row. A subquery becomes membership in the ids the
  subquery selects. That is why one query, and not a list of ids, can
  answer a rule that tests a subject's reach over rows.
  """

  alias Mediate.Error

  @schema NimbleOptions.new!(
            column: [type: :atom, doc: "The column of the kind's schema that holds the value."],
            subquery: [
              type: {:fun, 2},
              doc:
                "A function of the subject and the environment. It returns a query that selects " <>
                  "`%{id: ..., value: ...}`, with the value as text."
            ]
          )

  @reserved :environment

  @enforce_keys [:name, :source]
  defstruct [:name, :source]

  @typedoc "Where an attribute's value comes from."
  @type source ::
          {:column, atom()} | {:subquery, (Mediate.subject(), Mediate.environment() -> Ecto.Queryable.t())}

  @typedoc "The attribute values of one row, by the name the declarations gave."
  @type values :: %{atom() => term()}

  @typedoc "One attribute declaration: the name a policy reads, and where its value comes from."
  @type t :: %__MODULE__{name: atom(), source: source()}

  @doc "The attribute name the request-time facts travel under. No declaration can take it."
  @spec reserved() :: atom()
  def reserved, do: @reserved

  @doc "The schema of an attribute declaration's options."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "The declaration, or the reason it is not one."
  @spec new(atom(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(name, options) when is_atom(name) and is_list(options) do
    with :ok <- available(name),
         {:ok, validated} <- validate(name, options),
         {:ok, source} <- source(name, validated) do
      {:ok, %__MODULE__{name: name, source: source}}
    end
  end

  @doc "`new/2`, but it raises the error. A declaration in a module body calls this one."
  @spec new!(atom(), keyword()) :: t()
  def new!(name, options) when is_atom(name) and is_list(options) do
    case new(name, options) do
      {:ok, attribute} -> attribute
      {:error, error} -> raise error
    end
  end

  @doc "Whether the attribute reads a column of the row."
  @spec column?(t()) :: boolean()
  def column?(%__MODULE__{source: {:column, _column}}), do: true
  def column?(%__MODULE__{}), do: false

  defp available(@reserved), do: {:error, invalid(@reserved, "is the name the request-time facts travel under")}
  defp available(_name), do: :ok

  defp validate(name, options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(name, Exception.message(error))}
    end
  end

  defp source(name, validated) do
    case {validated[:column], validated[:subquery]} do
      {column, nil} when is_atom(column) and not is_nil(column) -> {:ok, {:column, column}}
      {nil, subquery} when is_function(subquery, 2) -> {:ok, {:subquery, subquery}}
      {nil, nil} -> {:error, invalid(name, "names neither a column nor a subquery")}
      {_column, _subquery} -> {:error, invalid(name, "names both a column and a subquery")}
    end
  end

  defp invalid(name, detail), do: Error.invalid(:attribute, "attribute #{name} " <> detail)
end
