defmodule Mediate.Postgres.Migration do
  @moduledoc """
  The helpers a migration calls. This is the only place the package writes
  DDL. Every statement runs through the repo the caller passes, under the
  library exemption, so the seam mediates a migration like any other call.

  - `protect!/2` enables row-level security on a table and forces it, so
    the policies apply to the table's owner as well.
  - `policy!/2` adds the `SELECT` policy of one operation. The helper
    writes the operation guard itself,
    `current_setting('mediate.operation', true) = '<operation>'`, and
    joins the caller's expression to it. Permissive policies combine with
    OR, so without the guard the policy of one operation widens another.
    With it, only the policy of the operation in force can hold.
  - `gate!/2` adds the write policy of one operation. An answer reads its
    `USING` expression before a write. The database applies its
    `WITH CHECK` expression to the write itself. An operation whose write
    is an insert has no row to read first. So its gate is an `INSERT`
    policy and carries the `WITH CHECK` expression alone. A gate
    carries no operation guard, so the database refuses a write that
    violates it whether or not anything asked first.
  - `admit!/2` adds a permissive `true` policy for one command. Forced
    row-level security refuses every statement no policy admits, so a table
    that takes an insert or a delete outside a decision needs one.
  - `exempt!/2` adds the policy that admits one role's statements while no
    operation is in force. That is the state the seam leaves behind when it
    admits a call outside a decision. A role that reads every row whatever
    the settings say takes the same policy without that clause.
  - `grant!/2` grants a role the table privileges it needs. Row-level
    security narrows what a role can reach. The grant is what lets it reach
    the table at all, and the two go together.
  - `publish!/2` reads the policies back from `pg_policy` and emits the
    policy version, in the transaction the migration is already in.
    `docs/events.md` §4 has the event.

  Every name a helper puts into a statement passes a check first. A name
  that passes is a plain lowercase identifier within the length an
  identifier can hold. A name that fails raises, and the raise says which
  name it refused. The migration's author writes an expression, and it
  reaches the database as the author wrote it.
  """

  alias Mediate.PolicyVersion
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Infrastructure.Name
  alias Mediate.Postgres.Policy
  alias Mediate.Postgres.Version

  @exemption {:exempt, :library}
  @content_bytes 65_536
  @commands ~w(select insert update delete)a
  @guard "current_setting('mediate.operation', true)"

  @doc "Enable row-level security on the table and force it on the table's owner too."
  @spec protect!(module(), String.t() | atom()) :: :ok
  def protect!(repo, table) when is_atom(repo) do
    name = Name.check!(table, :table)
    run!(repo, "ALTER TABLE #{name} ENABLE ROW LEVEL SECURITY")
    run!(repo, "ALTER TABLE #{name} FORCE ROW LEVEL SECURITY")
  end

  @doc "Add the `SELECT` policy of one operation. Requires `table:`, `operation:`, and `using:`."
  @spec policy!(module(), keyword()) :: :ok
  def policy!(repo, options) when is_atom(repo) and is_list(options) do
    table = Name.check!(Keyword.fetch!(options, :table), :table)
    operation = Name.check!(Keyword.fetch!(options, :operation), :operation)
    using = Keyword.fetch!(options, :using)
    name = Name.check!(Policy.scope_name(operation), :policy)

    run!(
      repo,
      "CREATE POLICY #{name} ON #{table} FOR SELECT USING (#{@guard} = '#{operation}' AND (#{using}))"
    )
  end

  @doc """
  Add the write gate of one operation. Requires `table:` and
  `operation:`. Takes `command:`, `:update` by default. An update gate
  requires `using:` and `with_check:`. An insert gate requires
  `with_check:` alone.
  """
  @spec gate!(module(), keyword()) :: :ok
  def gate!(repo, options) when is_atom(repo) and is_list(options) do
    table = Name.check!(Keyword.fetch!(options, :table), :table)
    operation = Name.check!(Keyword.fetch!(options, :operation), :operation)
    name = Name.check!(Policy.gate_name(operation), :policy)
    {clause, shape} = gate(Keyword.get(options, :command, :update), options)

    run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
  end

  @doc "Add a permissive `true` policy for one command. Requires `table:` and `command:`."
  @spec admit!(module(), keyword()) :: :ok
  def admit!(repo, options) when is_atom(repo) and is_list(options) do
    table = Name.check!(Keyword.fetch!(options, :table), :table)
    command = Keyword.fetch!(options, :command)
    {clause, shape} = shape(command, "true")
    name = Name.check!("mediate_admit_#{command}", :policy)
    run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
  end

  @doc """
  Add the policy that admits a role's statements outside a decision.
  Requires `table:` and `to:`. Takes `commands:`, every command by
  default. Takes `outside_decision:`, `false` where the role holds the
  policy whatever operation is in force.
  """
  @spec exempt!(module(), keyword()) :: :ok
  def exempt!(repo, options) when is_atom(repo) and is_list(options) do
    table = Name.check!(Keyword.fetch!(options, :table), :table)
    role = Name.check!(Keyword.fetch!(options, :to), :role)
    predicate = exemption(role, Keyword.get(options, :outside_decision, true))

    Enum.each(Keyword.get(options, :commands, @commands), fn command ->
      {clause, shape} = shape(command, predicate)
      name = Name.check!("mediate_exempt_#{role}_#{command}", :policy)
      run!(repo, "CREATE POLICY #{name} ON #{table} FOR #{clause} #{shape}")
    end)
  end

  @doc "Grant a role privileges on a table. Requires `table:`, `to:`, and `commands:`."
  @spec grant!(module(), keyword()) :: :ok
  def grant!(repo, options) when is_atom(repo) and is_list(options) do
    table = Name.check!(Keyword.fetch!(options, :table), :table)
    role = Name.check!(Keyword.fetch!(options, :to), :role)
    commands = Keyword.fetch!(options, :commands)
    granted = Enum.map_join(commands, ", ", &granted/1)
    run!(repo, "GRANT #{granted} ON #{table} TO #{role}")
  end

  @doc """
  Read the policies on those tables back and emit the policy version.
  Requires `tables:`, `version:`, `author:`, and `approval:`. Takes `at:`
  and `content_bytes:`. The caller passes the moment, and the helper does
  not read the configured clock, because a migration runs before the
  configuration boots.
  """
  @spec publish!(module(), keyword()) :: PolicyVersion.t()
  def publish!(repo, options) when is_atom(repo) and is_list(options) do
    tables = Enum.map(Keyword.fetch!(options, :tables), &Name.check!(&1, :table))
    policies = Catalog.policies!(repo, tables)
    version = Version.of(Mediate.Postgres, policies, published(options))
    {:ok, ^version} = Version.publish(version)

    version
  end

  defp published(options) do
    [
      version: Keyword.fetch!(options, :version),
      author: Keyword.fetch!(options, :author),
      approval: Keyword.fetch!(options, :approval),
      at: Keyword.get_lazy(options, :at, &DateTime.utc_now/0),
      content_bytes: Keyword.get(options, :content_bytes, @content_bytes)
    ]
  end

  defp gate(:update, options) do
    using = Keyword.fetch!(options, :using)
    {"UPDATE", "USING (#{using}) WITH CHECK (#{Keyword.fetch!(options, :with_check)})"}
  end

  defp gate(:insert, options), do: {"INSERT", "WITH CHECK (#{Keyword.fetch!(options, :with_check)})"}

  defp exemption(role, true), do: "current_user = '#{role}' AND coalesce(#{@guard}, '') = ''"
  defp exemption(role, false), do: "current_user = '#{role}'"

  defp granted(:select), do: "SELECT"
  defp granted(:insert), do: "INSERT"
  defp granted(:update), do: "UPDATE"
  defp granted(:delete), do: "DELETE"

  defp shape(:insert, predicate), do: {"INSERT", "WITH CHECK (#{predicate})"}
  defp shape(:delete, predicate), do: {"DELETE", "USING (#{predicate})"}
  defp shape(:select, predicate), do: {"SELECT", "USING (#{predicate})"}
  defp shape(:update, predicate), do: {"UPDATE", "USING (#{predicate}) WITH CHECK (#{predicate})"}

  defp run!(repo, statement) do
    _result = repo.query!(statement, [], mediate: @exemption)
    :ok
  end
end
