defmodule Mediate.Rbac.Binding do
  @moduledoc """
  What `Mediate.Rbac` needs beyond the configuration: the policy module
  and the mediated repo its rules read through. `bind/1` validates the pair
  and keeps it for the life of the VM, as `Mediate.Config.boot!/1` keeps
  the configuration. `override/1` puts a binding in the current process for
  the rest of its life. `resolve/0` reads it from the caller and from its
  `$callers` chain. So a test binds its own policy and repo and leaves the
  boot binding alone.
  """

  alias Mediate.Error

  @schema NimbleOptions.new!(
            policy: [type: :atom, required: true, doc: "A module that uses `Mediate.Rbac.Policy`."],
            repo: [type: :atom, required: true, doc: "The mediated repo the rules read through."]
          )

  @enforce_keys [:policy, :repo]
  defstruct @enforce_keys

  @type t :: %__MODULE__{policy: module(), repo: module()}

  @doc "The schema of the binding's options."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "Validates the pair into the struct."
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(options) when is_list(options) do
    with {:ok, validated} <- validate(options),
         :ok <- policy?(validated[:policy]) do
      {:ok, %__MODULE__{policy: validated[:policy], repo: validated[:repo]}}
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

  @doc "`bind/1`, but raises the error."
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
      %__MODULE__{} = base -> new(Keyword.merge(to_keyword(base), overrides))
      nil when overrides == [] -> {:error, invalid("nothing bound and no override")}
      nil -> new(overrides)
    end
  end

  @doc "The binding as the keyword list `new/1` accepts."
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{policy: policy, repo: repo}), do: [policy: policy, repo: repo]

  defp validate(options) do
    case NimbleOptions.validate(options, @schema) do
      {:ok, validated} -> {:ok, validated}
      {:error, %NimbleOptions.ValidationError{} = error} -> {:error, invalid(Exception.message(error))}
    end
  end

  defp policy?(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__mediate_code__, 1) do
      :ok
    else
      {:error, invalid("#{inspect(module)} did not use Mediate.Rbac.Policy")}
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
