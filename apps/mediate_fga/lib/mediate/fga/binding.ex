defmodule Mediate.Fga.Binding do
  @moduledoc """
  What `Mediate.Fga` needs beyond the configuration entry, which carries
  the endpoint and the store alone:

  - the mediated repo the adapter reads the markers and the tables through
  - the model text the adapter publishes the store from
  - the module that maps rows to tuples
  - who wrote and who approved that model
  - the guard, where the application has a precondition the model cannot hold

  `bind/1` validates them and keeps them for the life of the VM, as
  `Mediate.Config.boot!/1` keeps the configuration. `override/1` puts a
  binding in the current process for the rest of its life. `resolve/0`
  reads it from the current process and from its `$callers` chain. So a
  test binds a repo and a mapping of its own and leaves the boot binding
  alone.

  The repo is here and not in the configuration entry, because what a
  drain reads is the application's own. The markers and the tables the
  mapping answers from live where the application's rows are, not where
  the engine is. The model path is here for the same reason. The store
  holds tuples under a model the server names by id, and the text those
  ids come from is the application's file.
  """

  alias Mediate.Error
  alias Mediate.Fga.Guard
  alias Mediate.Fga.Model
  alias Mediate.Fga.TupleMapping

  @schema NimbleOptions.new!(
            repo: [type: :atom, required: true, doc: "The mediated repo that holds the outbox and the tables."],
            model: [
              type: :string,
              required: true,
              doc: "The file that holds the model text the adapter publishes."
            ],
            mapping: [
              type: :atom,
              required: true,
              doc: "The `Mediate.Fga.TupleMapping` implementation for this application's tables."
            ],
            guard: [
              type: :atom,
              default: nil,
              doc: "The `Mediate.Fga.Guard` every callback consults before it asks, where there is one."
            ],
            author: [type: {:or, [:string, nil]}, default: nil, doc: "Who wrote the model."],
            approval: [type: {:or, [:string, nil]}, default: nil, doc: "The approval the model carries."]
          )

  @enforce_keys [:repo, :model, :mapping]
  defstruct [:repo, :model, :mapping, :guard, :author, :approval]

  @typedoc "The bound repo, the model file, the tuple mapping, and the guard."
  @type t :: %__MODULE__{
          repo: module(),
          model: Path.t(),
          mapping: module(),
          guard: module() | nil,
          author: String.t() | nil,
          approval: String.t() | nil
        }

  @doc "The schema of the binding's options. Fields: #{NimbleOptions.docs(@schema)}"
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "Validates the options into the struct."
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(options) when is_list(options) do
    with {:ok, validated} <- validate(options),
         :ok <- implements?(validated[:mapping], TupleMapping),
         :ok <- implements?(validated[:guard], Guard) do
      {:ok, struct!(__MODULE__, validated)}
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

  @doc "`bind/1`, and raises on error."
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
      model: binding.model,
      mapping: binding.mapping,
      guard: binding.guard,
      author: binding.author,
      approval: binding.approval
    ]
  end

  @doc "The bound model as text, read from the file the binding names."
  @spec text(t()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(%__MODULE__{model: path}) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, invalid("#{path} could not be read: #{:file.format_error(reason)}")}
    end
  end

  @doc "The bound model as the server takes it."
  @spec compiled(t()) :: {:ok, Model.t()} | {:error, Error.t()}
  def compiled(%__MODULE__{} = binding) do
    with {:ok, text} <- text(binding), do: Model.compile(text)
  end

  defp validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(Exception.message(error))}
    end
  end

  defp implements?(nil, _behaviour), do: :ok

  defp implements?(module, behaviour) do
    if behaviour in behaviours(module) do
      :ok
    else
      {:error, invalid("#{inspect(module)} is no #{inspect(behaviour)}")}
    end
  end

  defp behaviours(module) do
    if Code.ensure_loaded?(module) do
      for {:behaviour, list} <- module.module_info(:attributes), behaviour <- list, do: behaviour
    else
      []
    end
  end

  defp invalid(detail), do: Error.invalid(:binding, detail)

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
