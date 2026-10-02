defmodule Mediate.Cerbos.Binding do
  @moduledoc """
  What `Mediate.Cerbos` needs beyond the configuration entry, which
  carries the server's address alone:

  - the mediated repo the engine reads the attribute values through
  - the declarations, a module that used `Mediate.Cerbos.Declarations`
  - the policy directory, and the commit the server serves from it
  - who wrote that commit, and who approved it

  `bind/1` validates them once and keeps them for the life of the VM, as
  `Mediate.Config.boot!/1` keeps the configuration. `override/1` puts a
  binding in the current process for the rest of its life. `resolve/0`
  reads it from the current process and from its `$callers` chain. So a
  test binds its own policy directory and leaves the boot binding alone.

  After the configuration boots, the deployment binds and releases:

      {:ok, _binding} =
        Mediate.Cerbos.Binding.bind(
          repo: MyApp.Repo,
          declarations: MyApp.Declarations,
          policy_dir: "priv/policies",
          commit: "9c1f4ae",
          author: "the policy owner",
          approval: "the change record"
        )

      {:ok, _release} = Mediate.Cerbos.release()

  The commit is the policy version every verdict under this binding
  names. `Mediate.Cerbos.Version` says why the commit, and not a digest
  of the files or the `version` field of a policy.

  Every block's schema names a row by one primary key column, because a
  resource id is one value. A schema with a composite key or none fails
  `bind/1`, so `schema_and_key/2` answers `nil` for an undeclared block
  alone.
  """

  alias Mediate.Cerbos.Declarations
  alias Mediate.Error

  @schema NimbleOptions.new!(
            repo: [type: :atom, required: true, doc: "The mediated repo the engine reads the attribute values through."],
            declarations: [
              type: :atom,
              required: true,
              doc: "The module that used `Mediate.Cerbos.Declarations`."
            ],
            policy_dir: [
              type: :string,
              required: true,
              doc: "The directory of the policy files the server reads."
            ],
            commit: [
              type: :string,
              required: true,
              doc: "The commit of the policy repository at that directory: the policy version."
            ],
            author: [type: {:or, [:string, nil]}, default: nil, doc: "Who wrote the commit."],
            approval: [type: {:or, [:string, nil]}, default: nil, doc: "The approval the commit carries."]
          )

  @enforce_keys [:repo, :declarations, :policy_dir, :commit]
  defstruct [:repo, :declarations, :policy_dir, :commit, :author, :approval]

  @typedoc "The bound repo, the declarations, the policy directory, and the commit that names the version."
  @type t :: %__MODULE__{
          repo: module(),
          declarations: Declarations.t(),
          policy_dir: Path.t(),
          commit: String.t(),
          author: String.t() | nil,
          approval: String.t() | nil
        }

  @doc "The schema of the binding's options."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "The struct from the options, or the reason they make none."
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(options) when is_list(options) do
    with {:ok, validated} <- validate(options),
         :ok <- declares?(validated[:declarations]),
         :ok <- keyed?(validated[:declarations]) do
      {:ok, struct!(__MODULE__, validated)}
    end
  end

  @doc "Validates the options once at boot and keeps the binding for `resolve/0`."
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

  @doc "Overrides the binding's fields around a function, then puts the previous override back."
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
        {:error, invalid("nothing bound and no override; call Mediate.Cerbos.Binding.bind!/1 at boot")}

      nil ->
        new(overrides)
    end
  end

  @doc "The binding as the keyword list `new/1` accepts."
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = binding) do
    [
      repo: binding.repo,
      declarations: binding.declarations,
      policy_dir: binding.policy_dir,
      commit: binding.commit,
      author: binding.author,
      approval: binding.approval
    ]
  end

  @doc "The schema and the one primary key of a block, or `nil` for a block no declaration names."
  @spec schema_and_key(t(), Declarations.block()) :: {module(), atom()} | nil
  def schema_and_key(%__MODULE__{declarations: declarations}, {side, name} = block)
      when side in [:principal, :resource] and is_atom(name) do
    case Declarations.schema_of(declarations, block) do
      nil ->
        nil

      schema ->
        [key] = schema.__schema__(:primary_key)
        {schema, key}
    end
  end

  defp validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(Exception.message(error))}
    end
  end

  defp declares?(declarations) do
    if Declarations.declares?(declarations) do
      :ok
    else
      {:error,
       invalid(
         "#{inspect(declarations)} did not use Mediate.Cerbos.Declarations; " <>
           "add use Mediate.Cerbos.Declarations or bind the module that does"
       )}
    end
  end

  defp keyed?(declarations) do
    case Enum.find(Declarations.blocks(declarations), &(length(primary_key(&1)) != 1)) do
      nil ->
        :ok

      {side, name, schema} ->
        {:error,
         invalid(
           "#{inspect(declarations)} declares #{side} #{inspect(name)} on #{inspect(schema)}, " <>
             "whose primary key is not one column; Mediate.Cerbos names a row by one key column"
         )}
    end
  end

  defp primary_key({_side, _name, schema}), do: schema.__schema__(:primary_key)

  defp invalid(text), do: Error.invalid(:binding, text)

  # This reads the override from the current process, then from each process
  # in its `$callers` chain, nearest first. The first one found wins.
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
