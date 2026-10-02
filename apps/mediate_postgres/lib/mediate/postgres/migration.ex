defmodule Mediate.Postgres.Migration do
  @moduledoc """
  The helpers a migration calls. This is the only place the package writes
  DDL. Every statement runs through the repo the caller passes, under the
  library exemption, so the mediated repo sees a migration like any other
  call.

  - `protect!/2` enables row-level security on a table and forces it, so
    the rules apply to the table's owner as well.
  - `filter!/2` adds the filter rule of one action: the `SELECT` rule that
    narrows the rows of that action. The helper writes the action guard
    itself, `current_setting('mediate.action', true) = '<action>'`, and
    joins the caller's expression to it. Permissive policies combine with
    OR, so without the guard the rule of one action widens another. With
    it, only the rule of the action in force can hold.
  - `gate!/2` adds the gate rule of one action. A verdict reads its
    `USING` expression before a write. The database applies its
    `WITH CHECK` expression to the write itself. An action whose write is
    an insert has no row to read first. So its gate is an `INSERT` rule
    and carries the `WITH CHECK` expression alone. A gate carries no
    action guard, so the database refuses a write that violates it
    whether or not anything asked first.
  - `admit!/2` adds a permissive `true` rule for one command. Forced
    row-level security refuses every statement no rule admits, so a table
    that takes an insert or a delete outside a decision needs one.
  - `exempt!/2` adds the rule that admits one role's statements while no
    action is in force. That is the state the mediated repo leaves behind
    when it admits a call outside a decision. A role that reads every row
    whatever the settings say takes the same rule with `always: true`.
  - `privileges!/2` grants a role the table privileges it needs.
    Row-level security narrows what a role can reach. The privileges are
    what let it reach the table at all, and the two go together.
  - `release!/2` reads the rules back from `pg_policy` and publishes the
    policy release, in the transaction the migration is already in. The
    events document under "Policy release" has the event.

  Every name a helper puts into a statement passes an identifier check
  first. A name that passes is a lowercase identifier within the length
  an identifier can hold. A name that fails raises, and the raise says
  which name it refused and what kind of name it was. The migration's
  author writes an expression, and it reaches the database as the author
  wrote it.
  """

  alias Mediate.PolicyRelease
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Domain.Identifier
  alias Mediate.Postgres.Rule
  alias Mediate.Postgres.Version

  @exemption {:exempt, :library}
  @policy_text_bytes 65_536
  @commands ~w(select insert update delete)a
  @guard "current_setting('mediate.action', true)"

  @doc "Enables row-level security on the table and forces it on the table's owner too."
  @spec protect!(module(), String.t() | atom()) :: :ok
  def protect!(repo, table) when is_atom(repo) do
    name = Identifier.check!(table, :table)
    run!(repo, "ALTER TABLE #{name} ENABLE ROW LEVEL SECURITY")
    run!(repo, "ALTER TABLE #{name} FORCE ROW LEVEL SECURITY")
  end

  @doc "Adds the filter rule of one action. Requires `table:`, `action:`, and `using:`."
  @spec filter!(module(), keyword()) :: :ok
  def filter!(repo, options) when is_atom(repo) and is_list(options) do
    table = Identifier.check!(Keyword.fetch!(options, :table), :table)
    action = Identifier.check!(Keyword.fetch!(options, :action), :action)
    using = Keyword.fetch!(options, :using)
    name = Identifier.check!(Rule.filter_name(action), :policy)

    run!(repo, "CREATE POLICY #{name} ON #{table} FOR SELECT USING (#{@guard} = '#{action}' AND (#{using}))")
  end

  @doc """
  Adds the gate rule of one action. Requires `table:` and `action:`. Takes
  `command:`, `:update` by default. An update gate requires `using:` and
  `with_check:`. An insert gate requires `with_check:` alone.
  """
  @spec gate!(module(), keyword()) :: :ok
  def gate!(repo, options) when is_atom(repo) and is_list(options) do
    table = Identifier.check!(Keyword.fetch!(options, :table), :table)
    action = Identifier.check!(Keyword.fetch!(options, :action), :action)
    name = Identifier.check!(Rule.gate_name(action), :policy)
    {clause, shape} = gate(Keyword.get(options, :command, :update), options)

    run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
  end

  @doc "Adds a permissive `true` rule for one command. Requires `table:` and `command:`."
  @spec admit!(module(), keyword()) :: :ok
  def admit!(repo, options) when is_atom(repo) and is_list(options) do
    table = Identifier.check!(Keyword.fetch!(options, :table), :table)
    command = Keyword.fetch!(options, :command)
    {clause, shape} = shape(command, "true")
    name = Identifier.check!("mediate_admit_#{command}", :policy)
    run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
  end

  @doc """
  Adds the rule that admits a role's statements outside a decision.
  Requires `table:` and `to:`. Takes `commands:`, every command by
  default. Takes `always:`, `true` where the role holds the rule whatever
  action is in force.
  """
  @spec exempt!(module(), keyword()) :: :ok
  def exempt!(repo, options) when is_atom(repo) and is_list(options) do
    table = Identifier.check!(Keyword.fetch!(options, :table), :table)
    role = Identifier.check!(Keyword.fetch!(options, :to), :role)
    predicate = exemption(role, Keyword.get(options, :always, false))

    Enum.each(Keyword.get(options, :commands, @commands), fn command ->
      {clause, shape} = shape(command, predicate)
      name = Identifier.check!("mediate_exempt_#{role}_#{command}", :policy)
      run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
    end)
  end

  @doc "Grants a role its privileges on a table. Requires `table:`, `to:`, and `commands:`."
  @spec privileges!(module(), keyword()) :: :ok
  def privileges!(repo, options) when is_atom(repo) and is_list(options) do
    table = Identifier.check!(Keyword.fetch!(options, :table), :table)
    role = Identifier.check!(Keyword.fetch!(options, :to), :role)
    commands = Keyword.fetch!(options, :commands)
    granted = Enum.map_join(commands, ", ", &granted/1)
    run!(repo, "GRANT #{granted} ON #{table} TO #{role}")
  end

  @doc """
  Reads the rules on those tables back and publishes the policy release.
  Requires `tables:`, `policy_version:`, `author:`, and `approval:`. Takes
  `released_at:` and `policy_text_bytes:`. The caller passes the moment,
  and the helper does not read the configured clock, because a migration
  runs before the configuration boots.
  """
  @spec release!(module(), keyword()) :: PolicyRelease.t()
  def release!(repo, options) when is_atom(repo) and is_list(options) do
    tables = Enum.map(Keyword.fetch!(options, :tables), &Identifier.check!(&1, :table))
    release = Version.release(Mediate.Postgres, Catalog.rules(repo, tables), released(options))
    :ok = PolicyRelease.publish(release)

    release
  end

  defp released(options) do
    [
      policy_version: Keyword.fetch!(options, :policy_version),
      author: Keyword.fetch!(options, :author),
      approval: Keyword.fetch!(options, :approval),
      released_at: Keyword.get_lazy(options, :released_at, &DateTime.utc_now/0),
      policy_text_bytes: Keyword.get(options, :policy_text_bytes, @policy_text_bytes)
    ]
  end

  defp gate(:update, options) do
    using = Keyword.fetch!(options, :using)
    {"UPDATE", "USING (#{using}) WITH CHECK (#{Keyword.fetch!(options, :with_check)})"}
  end

  defp gate(:insert, options), do: {"INSERT", "WITH CHECK (#{Keyword.fetch!(options, :with_check)})"}

  defp exemption(role, false), do: "current_user = '#{role}' AND coalesce(#{@guard}, '') = ''"
  defp exemption(role, true), do: "current_user = '#{role}'"

  defp granted(:select), do: "SELECT"
  defp granted(:insert), do: "INSERT"
  defp granted(:update), do: "UPDATE"
  defp granted(:delete), do: "DELETE"

  defp shape(:insert, predicate), do: {"INSERT", "WITH CHECK (#{predicate})"}
  defp shape(:delete, predicate), do: {"DELETE", "USING (#{predicate})"}
  defp shape(:select, predicate), do: {"SELECT", "USING (#{predicate})"}
  defp shape(:update, predicate), do: {"UPDATE", "USING (#{predicate}) WITH CHECK (#{predicate})"}

  defp run!(repo, statement) do
    _result = repo.query!(statement, [], authorized_by: @exemption)
    :ok
  end
end
