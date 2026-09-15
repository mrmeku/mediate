defmodule Mediate.Cerbos.Infrastructure.Decide do
  # The answers the adapter gives: the attribute values it reads, one
  # request to the sidecar, and the effects it answered turned into answers.
  #
  # A decision is one call that carries the object asked about. A scope is
  # one call for the object type, and its filter becomes the rule. An effect
  # of allow is an allowance by the policy the sidecar matched. Anything
  # else is a denial that names the policy the sidecar evaluated, where it
  # named one. A denial does not read as a rule that denied. The sidecar
  # names the policy it evaluated whether a rule denied or no rule allowed,
  # and the two are not the same claim.
  #
  # A resource the sidecar answered nothing about gets a denial by default.
  # A failure of the call answers the failure's detail, which the adapter
  # turns into an engine error.
  #
  # Each call carries the request-time facts with the subject's attributes.
  # So a rule about the moment of the request reads the moment the port
  # stamped it with, and not the sidecar's own clock.
  @moduledoc false

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Answer
  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Client
  alias Mediate.Cerbos.Infrastructure.Plan
  alias Mediate.Cerbos.Infrastructure.Values
  alias Mediate.Cerbos.Request

  @fallback [:mediate, :cerbos, :scope_fallback]

  @doc "The telemetry event a plan this adapter cannot express emits, once per scope that falls back."
  @spec fallback_event() :: [atom()]
  def fallback_event, do: @fallback

  @doc "The answer for one object, with the policy the sidecar matched under `meta[:matched]`."
  @spec one(Binding.t(), Client.address(), Mediate.subject(), atom(), Mediate.object(), Mediate.environment()) ::
          {:ok, Answer.t()} | {:error, String.t()}
  def one(
        %Binding{} = binding,
        address,
        {_kind, _account} = subject,
        operation,
        {type, _id} = object,
        %{now: _now} = request
      )
      when is_binary(address) and is_atom(operation) do
    with {:ok, body} <- asked(binding, subject, operation, type, object, request),
         {:ok, answered} <- Client.check_resources(address, body) do
      effect(binding, answered, operation, object)
    end
  end

  @doc """
  The rule for an object type: the plan the sidecar answered, compiled
  against the declarations. A plan that admits no row is a denial with the
  rule `false`. A plan this adapter does not express emits
  `fallback_event/0` and fails.
  """
  @spec scoped(Binding.t(), Client.address(), Mediate.subject(), atom(), atom(), Mediate.environment()) ::
          {:ok, Mediate.Adapter.scoped()} | {:error, String.t()}
  def scoped(%Binding{} = binding, address, {_kind, _account} = subject, operation, kind, %{now: _now} = request)
      when is_binary(address) and is_atom(operation) and is_atom(kind) do
    with {:ok, principal} <- Values.principal(binding, subject, request),
         body = Request.plan(subject, operation, kind, principal),
         {:ok, answered} <- Client.plan_resources(address, body) do
      compiled(binding, subject, request, operation, kind, answered)
    end
  end

  defp asked(binding, subject, operation, type, object, request) do
    with {:ok, principal} <- Values.principal(binding, subject, request),
         {:ok, by_id} <- Values.resources(binding, subject, type, [object], request) do
      {:ok, Request.check(subject, operation, principal, [{object, values(by_id, object)}])}
    end
  end

  defp effect(binding, answered, operation, object) do
    with {:ok, effects} <- effects(answered, operation) do
      {:ok, explanation(binding, Map.get(effects, key(object)))}
    end
  end

  defp matched(result, action) do
    case result["meta"]["actions"][action]["matchedPolicy"] do
      "NO_MATCH" -> nil
      policy -> policy
    end
  end

  defp answer("EFFECT_ALLOW", policy, version) do
    %Answer{verdict: :allow, reason: :allowed, version: version, meta: %{rule: policy}}
  end

  defp answer(_effect, policy, version) do
    %Answer{verdict: :deny, reason: :deny_by_default, version: version, meta: %{rule: policy}}
  end

  defp compiled(binding, subject, request, operation, kind, answered) do
    case Plan.dynamic(binding, subject, request, kind, Map.get(answered, "filter", %{})) do
      {:ok, rule} -> {:ok, {rule, allowed(binding, nil)}}
      :denied -> {:ok, {dynamic([_row], false), denied(binding, nil)}}
      {:error, detail} -> fallback(operation, kind, detail)
    end
  end

  defp fallback(operation, kind, detail) do
    :telemetry.execute(@fallback, %{}, %{operation: operation, kind: kind, detail: detail})
    {:error, detail}
  end

  # Keyed by kind and id, because that is how the answer names a resource.
  defp effects(%{"results" => results}, operation) when is_list(results) do
    action = Atom.to_string(operation)
    {:ok, Map.new(results, &{resource_key(&1), {effect(&1, action), matched(&1, action)}})}
  end

  defp effects(other, _operation) do
    {:error, "cerbos answered no results: " <> String.slice(inspect(other), 0, 200)}
  end

  defp resource_key(result), do: {result["resource"]["kind"], result["resource"]["id"]}

  defp effect(result, action), do: result["actions"][action]

  defp values(by_id, {_type, id}), do: Map.get(by_id, to_string(id), %{})

  defp key({type, id}), do: {Atom.to_string(type), to_string(id)}

  defp explanation(binding, {"EFFECT_ALLOW", policy}), do: explaining(allowed(binding, policy), List.wrap(policy))
  defp explanation(binding, {_effect, policy}), do: explaining(denied(binding, policy), [])
  defp explanation(binding, nil), do: explaining(denied(binding, nil), [])

  defp explaining(%Answer{} = answer, policies), do: %{answer | meta: Map.put(answer.meta, :matched, policies)}

  defp allowed(%Binding{commit: commit}, policy), do: answer("EFFECT_ALLOW", policy, commit)

  defp denied(%Binding{commit: commit}, policy), do: answer(nil, policy, commit)
end
