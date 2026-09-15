defmodule Mediate.Cerbos.Binding do
  @moduledoc """
  What `Mediate.Cerbos` needs beyond the configuration entry, which
  carries the sidecar's address alone:

  - the mediated repo the adapter reads the attribute values through
  - the module that declares those attributes
  - the policy directory, and the commit the sidecar serves from it
  - who wrote that commit, and who approved it

  `bind/1` validates them once and keeps them for the life of the VM, as
  `Mediate.Config.boot!/1` keeps the configuration. `override/1` puts a
  binding in the current process for the rest of its life. `resolve/0`
  reads it from the current process and from its `$callers` chain. So a
  test binds its own policy directory and leaves the boot binding alone.

  After the configuration boots, the application binds and publishes:

      {:ok, _binding} =
        Mediate.Cerbos.Binding.bind(
          repo: MyApp.Repo,
          attributes: MyApp.Attributes,
          policies: "priv/policies",
          commit: "9c1f4ae",
          author: "the policy owner",
          approval: "the change record"
        )

      {:ok, _event} = Mediate.Cerbos.publish()

  The commit is the version identifier every decision under this binding
  names. `Mediate.Cerbos.Version` says why the commit, and not a digest of
  the files or the `version` field of a policy.
  """

  alias Mediate.Cerbos.Attributes
  alias Mediate.Error

  @schema NimbleOptions.new!(
            repo: [type: :atom, required: true, doc: "The mediated repo the adapter reads the attribute values through."],
            attributes: [
              type: :atom,
              required: true,
              doc: "The module that used `Mediate.Cerbos.Attributes`."
            ],
            policies: [
              type: :string,
              required: true,
              doc: "The directory of the policy files the sidecar serves."
            ],
            commit: [
              type: :string,
              required: true,
              doc: "The commit of the policy repository at that directory, the version identifier."
            ],
            author: [type: {:or, [:string, nil]}, default: nil, doc: "Who wrote the commit."],
            approval: [type: {:or, [:string, nil]}, default: nil, doc: "The approval the commit carries."]
          )

  @enforce_keys [:repo, :attributes, :policies, :commit]
  defstruct [:repo, :attributes, :policies, :commit, :author, :approval]

  @type t :: %__MODULE__{
          repo: module(),
          attributes: Attributes.t(),
          policies: Path.t(),
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
         :ok <- declares?(validated[:attributes]) do
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

  @doc "`bind/1`, but it raises the error."
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
      %__MODULE__{} = base -> new(Keyword.merge(to_keyword(base), overrides))
      nil when overrides == [] -> {:error, invalid("nothing bound and no override")}
      nil -> new(overrides)
    end
  end

  @doc "The binding as the keyword list `new/1` accepts."
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = binding) do
    [
      repo: binding.repo,
      attributes: binding.attributes,
      policies: binding.policies,
      commit: binding.commit,
      author: binding.author,
      approval: binding.approval
    ]
  end

  @doc "The schema of a kind and its single primary key, or `nil` where no declaration names the kind with one."
  @spec target(t(), atom()) :: {module(), atom()} | nil
  def target(%__MODULE__{attributes: attributes}, kind) when is_atom(kind) do
    case Attributes.schema_of(attributes, kind) do
      nil -> nil
      schema -> keyed(schema)
    end
  end

  # A kind whose schema has a composite key or none has no single column an
  # object identifier names, so this adapter answers nothing about it.
  defp keyed(schema) do
    case schema.__schema__(:primary_key) do
      [key] -> {schema, key}
      _none_or_composite -> nil
    end
  end

  defp validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(Exception.message(error))}
    end
  end

  defp declares?(attributes) do
    if Attributes.declares?(attributes) do
      :ok
    else
      {:error, invalid("#{inspect(attributes)} did not use Mediate.Cerbos.Attributes")}
    end
  end

  defp invalid(detail), do: Error.invalid(:binding, detail)

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
