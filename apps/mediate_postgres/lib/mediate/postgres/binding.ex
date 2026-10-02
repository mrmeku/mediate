defmodule Mediate.Postgres.Binding do
  @moduledoc """
  What `Mediate.Postgres` needs beyond the configuration: the mediated
  repo whose connection carries the session settings, the schemas whose
  tables the rules protect and read, and the migration source whose
  highest version is the policy version. It is not an Ecto query binding.

  `bind/1` validates them and keeps them for the life of the VM, as
  `Mediate.Config.boot!/1` keeps the configuration. `override/1` puts a
  binding in the current process for the rest of its life. `resolve/0`
  reads it from the caller and from its `$callers` chain, and the nearest
  wins. So a test binds its own repo and leaves the boot binding alone.

  The schemas serve three lookups: a resource type to the table and
  primary key its verdicts run against, a table back to the schema whose
  declarations cover it, and the set of tables whose rules are the
  engine's business.
  """

  alias Mediate.Error
  alias Mediate.Schema

  @schema NimbleOptions.new!(
            repo: [type: :atom, required: true, doc: "The mediated repo the settings and the verdicts run through."],
            schemas: [
              type: {:list, :atom},
              required: true,
              doc: "The schemas, each with `use Mediate.Schema`, whose tables the rules protect and read."
            ],
            migration_source: [
              type: :string,
              default: "schema_migrations",
              doc: "The table whose highest version is the policy version, as Ecto names it."
            ]
          )

  @enforce_keys [:repo, :schemas, :migration_source]
  defstruct @enforce_keys

  @typedoc "The bound repo, the schemas whose tables the rules protect, and where the version comes from."
  @type t :: %__MODULE__{repo: module(), schemas: [module()], migration_source: String.t()}

  @doc "The schema of the binding's options."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "Validates the options into the struct."
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(options) when is_list(options) do
    with {:ok, validated} <- validate(options),
         :ok <- declared?(validated[:schemas]) do
      {:ok,
       %__MODULE__{
         repo: validated[:repo],
         schemas: validated[:schemas],
         migration_source: validated[:migration_source]
       }}
    end
  end

  @doc "Validates once at boot and keeps the binding for `resolve/0`."
  @spec bind(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def bind(options) when is_list(options) do
    with {:ok, %__MODULE__{} = binding} <- new(options) do
      :persistent_term.put(__MODULE__, binding)
      {:ok, binding}
    end
  end

  @doc "`bind/1`, and it raises the error."
  @spec bind!(keyword()) :: t()
  def bind!(options) when is_list(options) do
    case bind(options) do
      {:ok, binding} -> binding
      {:error, error} -> raise error
    end
  end

  @doc "Overrides the binding's fields for the rest of the current process."
  @spec override(keyword()) :: :ok
  def override(overrides) when is_list(overrides) do
    current = Process.get(__MODULE__, [])
    Process.put(__MODULE__, Keyword.merge(current, overrides))
    :ok
  end

  @doc "Overrides the binding's fields around a function. Puts the previous override back after it."
  @spec override(keyword(), (-> result)) :: result when result: term()
  def override(overrides, fun) when is_list(overrides) and is_function(fun, 0) do
    previous = Process.get(__MODULE__, [])
    :ok = override(overrides)

    try do
      fun.()
    after
      Process.put(__MODULE__, previous)
    end
  end

  @doc "The boot binding under the current process's overrides, or an error when neither exists."
  @spec resolve() :: {:ok, t()} | {:error, Error.t()}
  def resolve do
    overrides = overrides()

    case :persistent_term.get(__MODULE__, nil) do
      %__MODULE__{} = base ->
        new(Keyword.merge(to_keyword(base), overrides))

      nil when overrides == [] ->
        {:error, invalid("nothing bound and no override; call Mediate.Postgres.Binding.bind!/1 at boot")}

      nil ->
        new(overrides)
    end
  end

  @doc "The binding as the keyword list `new/1` accepts."
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = binding) do
    [repo: binding.repo, schemas: binding.schemas, migration_source: binding.migration_source]
  end

  @doc "The tables of the bound schemas, sorted."
  @spec tables(t()) :: [String.t()]
  def tables(%__MODULE__{schemas: schemas}) do
    schemas
    |> Enum.map(& &1.__schema__(:source))
    |> Enum.sort()
  end

  @doc "The table and single primary key of a resource type, or `nil` when no bound schema declares it."
  @spec table_of(t(), atom()) :: {String.t(), atom()} | nil
  def table_of(%__MODULE__{schemas: schemas}, resource_type) when is_atom(resource_type) do
    Enum.find_value(schemas, fn schema ->
      if Schema.resource_type_of(schema) == resource_type, do: single_key(schema)
    end)
  end

  @doc "The bound schema whose table is `table`, or `nil`."
  @spec schema_of(t(), String.t()) :: module() | nil
  def schema_of(%__MODULE__{schemas: schemas}, table) when is_binary(table) do
    Enum.find(schemas, &(&1.__schema__(:source) == table))
  end

  # A type whose key is not one column has no table here: a verdict names
  # a row by a single primary key or not at all.
  defp single_key(schema) do
    case schema.__schema__(:primary_key) do
      [column] -> {schema.__schema__(:source), column}
      _composite_or_none -> nil
    end
  end

  defp validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(Exception.message(error))}
    end
  end

  defp declared?(schemas) do
    case Enum.reject(schemas, &Schema.declares?/1) do
      [] ->
        :ok

      undeclared ->
        names = Enum.map_join(undeclared, ", ", &inspect/1)

        {:error,
         invalid("schemas: #{names} did not use Mediate.Schema; add use Mediate.Schema to each or drop it from schemas:")}
    end
  end

  defp invalid(text), do: Error.invalid(:binding, text)

  defp overrides do
    [self() | List.wrap(Process.get(:"$callers", []))]
    |> Enum.map(&overrides_of/1)
    |> Enum.find([], &(&1 != []))
  end

  defp overrides_of(pid) when pid == self(), do: Process.get(__MODULE__, [])

  defp overrides_of(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dictionary} -> Keyword.get(dictionary, __MODULE__, [])
      nil -> []
    end
  end
end
