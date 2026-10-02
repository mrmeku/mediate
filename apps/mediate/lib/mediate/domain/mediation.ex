defmodule Mediate.Domain.Mediation do
  @moduledoc false
  # The `authorized_by:` option, resolved. Every override puts this struct
  # back in the options in the option's place. So `prepare_query/3` and a
  # nested call Ecto makes on the caller's behalf see one shape. The option
  # accepts a `%Mediate.Decision{}`, `{:exempt, justification}` with a
  # non-empty justification, or `{:exempt, :library}`.
  #
  # `covered` is the set of schemas the decision covers beyond the root. It
  # is the closure of the root's covered associations. The mediation fills
  # it only when the decision names the root's own resource type.
  #
  # This module reads the option. `Mediate.Infrastructure.Option` reads the
  # caller and the process it ran in.

  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Exemption
  alias Mediate.Schema

  @schema NimbleOptions.new!(
            authorized_by: [
              type: {:custom, __MODULE__, :validate_option, []},
              doc:
                "A `%Mediate.Decision{}`, `{:exempt, justification}` with a non-empty justification, " <>
                  "or `{:exempt, :library}` from a `Mediate.*` caller."
            ]
          )

  @enforce_keys [:call, :decision, :exemption, :caller, :covered]
  defstruct @enforce_keys

  @type call :: {atom(), non_neg_integer()}
  @type root :: module() | String.t() | nil

  @type t :: %__MODULE__{
          call: call(),
          decision: Decision.t() | nil,
          exemption: Exemption.t() | nil,
          caller: module() | :any | nil,
          covered: [module()]
        }

  @doc "The schema of the `authorized_by:` option."
  @spec schema() :: NimbleOptions.t()
  def schema, do: @schema

  @doc "Whether the mediation admits a call outright: an exemption of either kind."
  @spec exempt?(t() | nil) :: boolean()
  def exempt?(%__MODULE__{exemption: %Exemption{}}), do: true
  def exempt?(_other), do: false

  @doc "The resource type the decision names, or `nil`."
  @spec resource_type(t() | nil) :: atom() | nil
  def resource_type(%__MODULE__{decision: %Decision{resource: {type, _id}}}), do: type
  def resource_type(_other), do: nil

  @doc "The schema an association leads to, through `through:` chains where needed."
  @spec related(module(), atom()) :: module() | nil
  def related(schema, name) when is_atom(schema) and is_atom(name) do
    case schema.__schema__(:association, name) do
      %{related: related} -> related
      %{through: [first | rest]} -> Enum.reduce(rest, related(schema, first), &related(&2, &1))
      _other -> nil
    end
  end

  @doc """
  The error a call the mediated repo refuses makes. It names the function
  and its arity, the root source, and the decision's resource type where
  the caller gave one. It names the caller where the repo can read it. It
  carries a detail where the reason is not the plain one.
  """
  @spec decision_missing(keyword()) :: Error.t()
  def decision_missing(parts) when is_list(parts) do
    call = "Repo.#{parts[:function]}/#{parts[:arity]}"

    %Error{
      reason: :decision_missing,
      message: call <> target(parts[:schema]) <> " " <> why(parts) <> from(parts[:caller])
    }
  end

  @doc "A mediation with no decision and no exemption, so a refusal can name the call."
  @spec empty(call()) :: t()
  def empty(call), do: %__MODULE__{call: call, decision: nil, exemption: nil, caller: nil, covered: []}

  @doc "The value the option holds, or a raised `NimbleOptions` error."
  @spec validate!(term()) :: Decision.t() | {:exempt, String.t()} | {:exempt, :library} | t()
  def validate!(value) do
    [authorized_by: value]
    |> NimbleOptions.validate!(@schema)
    |> Keyword.fetch!(:authorized_by)
  end

  @doc "The mediation a library exemption makes: the library's own channel, recorded against its caller."
  @spec library(call(), root(), module() | :any) :: t()
  def library(call, root, caller) when is_atom(caller) do
    exempted(call, caller, %Exemption{source: root, caller: caller, justification: "library", declared_by: :library})
  end

  @doc "The mediation a declared exemption makes: the justification the caller gave, recorded against it."
  @spec declared(call(), root(), module() | :any, String.t()) :: t()
  def declared(call, root, caller, justification) when is_atom(caller) and is_binary(justification) do
    exemption = %Exemption{source: root, caller: caller, justification: justification, declared_by: :caller}
    exempted(call, caller, exemption)
  end

  @doc """
  The mediation a decision makes, with the schemas it covers beyond the
  root. A denial raises here, so no call a denial answered reaches Ecto.
  """
  @spec decided(call(), root(), Decision.t()) :: t()
  def decided(_call, _root, %Decision{effect: :deny} = decision) do
    raise Error.denied(decision.subject, decision.action, decision.resource, decision.reason)
  end

  def decided(call, root, %Decision{} = decision) do
    %__MODULE__{call: call, decision: decision, exemption: nil, caller: nil, covered: covered(root, decision)}
  end

  @doc false
  @spec validate_option(term()) :: {:ok, term()} | {:error, String.t()}
  def validate_option(%Decision{} = decision), do: {:ok, decision}

  def validate_option({:exempt, justification} = value) when is_binary(justification) and justification != "",
    do: {:ok, value}

  def validate_option({:exempt, :library} = value), do: {:ok, value}
  def validate_option(%__MODULE__{} = mediation), do: {:ok, mediation}

  def validate_option(other) do
    {:error, "expected a %Mediate.Decision{}, {:exempt, justification}, or {:exempt, :library}, got: " <> inspect(other)}
  end

  defp exempted(call, caller, %Exemption{} = exemption) do
    %__MODULE__{call: call, decision: nil, exemption: exemption, caller: caller, covered: []}
  end

  defp covered(root, %Decision{resource: {type, _id}}) when is_atom(root) and not is_nil(root) do
    if Schema.resource_type_of(root) == type, do: closure([root], []), else: []
  end

  defp covered(_root, _decision), do: []

  defp target(nil), do: ""
  defp target(schema), do: " on " <> inspect(schema)

  defp why(parts) do
    case {parts[:detail], parts[:resource_type]} do
      {detail, _type} when is_binary(detail) -> detail
      {nil, nil} -> "carries no decision and no exemption"
      {nil, type} -> "carries a decision for #{inspect(type)}, which does not cover it"
    end
  end

  defp from(caller) when is_atom(caller) and caller not in [nil, :any], do: " (from #{inspect(caller)})"
  defp from(_caller), do: ""

  defp closure([], seen), do: Enum.reverse(seen)

  defp closure([schema | rest], seen) do
    related =
      schema
      |> Schema.covers_of()
      |> Enum.map(&related(schema, &1))
      |> Enum.reject(&(is_nil(&1) or &1 in seen or &1 in rest))

    closure(rest ++ related, [schema | seen])
  end
end
