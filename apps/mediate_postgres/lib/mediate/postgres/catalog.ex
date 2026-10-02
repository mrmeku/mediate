defmodule Mediate.Postgres.Catalog do
  @moduledoc """
  What the database says its own rules are. `read/1` asks three sources:

  - `pg_policy`, for every rule on the bound tables, with the `USING` and
    `WITH CHECK` expressions as `pg_get_expr/2` renders them
  - `pg_depend`, for the columns those expressions read
  - the migration source, for the highest version, which is the policy
    version a decision names

  `load/1` reads and keeps the result for the life of the VM, so no call
  on the request path pays for a catalog read, and the query counts of a
  mediated call stay what the shape tests expect. An application loads it
  at boot through `Mediate.Postgres.load_catalog/0`, after the binding,
  and loads again after a migration that runs under a live VM.
  `resolve/1` answers the kept catalog, and loads on first use for a
  caller that did not.

  Every statement runs through the bound repo's raw channel under the
  library exemption, so the mediated repo sees a catalog read like any
  other call.
  """

  alias Mediate.Error
  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Domain.Identifier
  alias Mediate.Postgres.Rule

  @exemption {:exempt, :library}

  @rules """
  SELECT p.polname, c.relname, p.polcmd::text,
         pg_get_expr(p.polqual, p.polrelid),
         pg_get_expr(p.polwithcheck, p.polrelid)
  FROM pg_policy p
  JOIN pg_class c ON c.oid = p.polrelid
  WHERE c.relname = ANY($1)
  ORDER BY c.relname, p.polname
  """

  @reads """
  SELECT referenced.relname, attribute.attname
  FROM pg_depend dependency
  JOIN pg_policy policy ON dependency.classid = 'pg_policy'::regclass AND dependency.objid = policy.oid
  JOIN pg_class protected ON protected.oid = policy.polrelid
  JOIN pg_class referenced
    ON dependency.refclassid = 'pg_class'::regclass AND dependency.refobjid = referenced.oid
  JOIN pg_attribute attribute
    ON attribute.attrelid = dependency.refobjid AND attribute.attnum = dependency.refobjsubid
  WHERE dependency.refobjsubid > 0 AND protected.relname = ANY($1)
  ORDER BY 1, 2
  """

  @enforce_keys [:policy_version, :rules, :reads]
  defstruct @enforce_keys

  @typedoc "The policy version, the rules of the bound tables, and the table and column of every read they make."
  @type t :: %__MODULE__{policy_version: String.t(), rules: [Rule.t()], reads: [{String.t(), String.t()}]}

  @doc """
  Reads the catalog now, whatever a previous call kept. A migration source
  that holds no version is an invalid catalog. A statement the driver
  refuses is an engine failure with the driver's text.
  """
  @spec read(Binding.t()) :: {:ok, t()} | {:error, Error.t()}
  def read(%Binding{repo: repo} = binding) do
    tables = Binding.tables(binding)

    with {:ok, policy_version} <- version(repo, binding.migration_source) do
      {:ok,
       %__MODULE__{
         policy_version: policy_version,
         rules: rules(repo, tables),
         reads: Enum.map(rows(repo, @reads, [tables]), &read_of/1)
       }}
    end
  rescue
    error in Error -> {:error, error}
    error -> {:error, %Error{reason: :engine_failed, message: "catalog read failed: " <> Exception.message(error)}}
  end

  @doc "Reads the catalog and keeps it for this binding. Every call after it answers what the database held now."
  @spec load(Binding.t()) :: {:ok, t()} | {:error, Error.t()}
  def load(%Binding{} = binding) do
    with {:ok, %__MODULE__{} = catalog} <- read(binding) do
      :persistent_term.put({__MODULE__, binding}, catalog)
      {:ok, catalog}
    end
  end

  @doc "`load/1`, and it raises the error."
  @spec load!(Binding.t()) :: t()
  def load!(%Binding{} = binding) do
    case load(binding) do
      {:ok, catalog} -> catalog
      {:error, error} -> raise error
    end
  end

  @doc "The kept catalog. A first call loads it."
  @spec resolve(Binding.t()) :: {:ok, t()} | {:error, Error.t()}
  def resolve(%Binding{} = binding) do
    case :persistent_term.get({__MODULE__, binding}, nil) do
      %__MODULE__{} = kept -> {:ok, kept}
      nil -> load(binding)
    end
  end

  @doc "The rules on those tables, as `pg_policy` holds them, for a caller with no binding."
  @spec rules(module(), [String.t()]) :: [Rule.t()]
  def rules(repo, tables) when is_atom(repo) and is_list(tables) do
    Enum.map(rows(repo, @rules, [tables]), &rule/1)
  end

  @doc "The filter rule of an action on a table, or `nil`."
  @spec filter_rule(t(), String.t(), atom()) :: Rule.t() | nil
  def filter_rule(%__MODULE__{} = catalog, table, action) when is_atom(action) do
    named(catalog, table, Rule.filter_name(Atom.to_string(action)))
  end

  @doc "The gate rule of an action on a table, or `nil`."
  @spec gate_rule(t(), String.t(), atom()) :: Rule.t() | nil
  def gate_rule(%__MODULE__{} = catalog, table, action) when is_atom(action) do
    named(catalog, table, Rule.gate_name(Atom.to_string(action)))
  end

  defp named(%__MODULE__{rules: rules}, table, name) do
    Enum.find(rules, &(&1.table == table and &1.name == name))
  end

  defp rule([name, table, command, using, with_check]) do
    %Rule{name: name, table: table, command: Rule.command(command), using: using, with_check: with_check}
  end

  defp read_of([table, column]), do: {table, column}

  defp version(repo, source) do
    case rows(repo, "SELECT max(version)::text FROM #{Identifier.check!(source, :migration_source)}", []) do
      [[version]] when is_binary(version) ->
        {:ok, version}

      _empty ->
        {:error,
         Error.invalid(
           :catalog,
           "#{source} holds no migration version; run the migrations before Mediate.Postgres.load_catalog/0"
         )}
    end
  end

  defp rows(repo, statement, params) do
    %{rows: rows} = repo.query!(statement, params, authorized_by: @exemption)
    rows
  end
end
