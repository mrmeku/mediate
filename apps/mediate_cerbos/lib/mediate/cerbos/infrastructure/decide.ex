defmodule Mediate.Cerbos.Infrastructure.Decide do
  @moduledoc false
  # The verdicts the engine gives: the attribute values it reads, one
  # request to the server, and the effects it answered turned into verdicts.
  #
  # A decision is one call that carries the resource asked about. A filter
  # is one call for the resource type, and its plan becomes the rule. An
  # effect of allow is `:rule_allowed` by the policy the server evaluated.
  # Anything else is `:no_rule_matched`, naming the policy the server
  # evaluated where it named one. A denial does not read as a rule that
  # denied. The server names the policy it evaluated whether a rule denied
  # or no rule allowed, and the two are not the same claim.
  #
  # A subject kind no block declares is `:subject_kind_unknown`, and a
  # resource type no block declares is `:no_rule_matched` naming the type,
  # before any query runs. A resource the server answered nothing about is
  # a failure, not a verdict, because a missing answer is a fault. A
  # failure of the call answers the failure's sentence, which the engine
  # turns into an engine error.
  #
  # Each call carries the context facts with the subject's attributes. So a
  # rule about the moment of the request reads the moment the library
  # stamped it with, and not the server's own clock. Each verdict names the
  # request id the body carried, which the server's audit log holds too.

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Client
  alias Mediate.Cerbos.Declarations
  alias Mediate.Cerbos.Domain.Plan
  alias Mediate.Cerbos.Infrastructure.Values
  alias Mediate.Cerbos.Request
  alias Mediate.Engine
  alias Mediate.Verdict

  @doc "The verdict for one resource, with the policy the server evaluated and the request id under `meta`."
  @spec one(Binding.t(), Client.address(), Mediate.subject(), atom(), Mediate.resource(), Mediate.context()) ::
          {:ok, Verdict.t()} | {:error, String.t()}
  def one(%Binding{} = binding, address, {kind, _account} = subject, action, {type, _id} = resource, context)
      when is_binary(address) and is_atom(action) do
    case undeclared(binding, kind, type) do
      nil ->
        with {:ok, body} <- asked(binding, subject, action, type, resource, context),
             {:ok, answered} <- Client.check_resources(address, body) do
          answered(binding, body, answered, action, resource)
        end

      %Verdict{} = verdict ->
        {:ok, verdict}
    end
  end

  @doc """
  The rule for a resource type: the plan the server answered, compiled
  against the declarations. A plan that admits no row is `:no_rule_matched`
  with the rule `false`. A plan the compiler refuses fails with the
  sentence that says why.
  """
  @spec filter(Binding.t(), Client.address(), Mediate.subject(), atom(), atom(), Mediate.context()) ::
          {:ok, Engine.filtered()} | {:error, String.t()}
  def filter(%Binding{} = binding, address, {kind, _account} = subject, action, type, context)
      when is_binary(address) and is_atom(action) and is_atom(type) do
    case undeclared(binding, kind, type) do
      nil -> planned(binding, address, subject, action, type, context)
      %Verdict{} = verdict -> {:ok, {dynamic([_row], false), verdict}}
    end
  end

  defp planned(binding, address, subject, action, type, context) do
    with {:ok, principal} <- Values.principal(binding, subject, context),
         body = Request.plan(subject, action, type, principal),
         {:ok, answered} <- Client.plan_resources(address, body) do
      compiled(binding, body, subject, action, type, context, Map.get(answered, "filter", %{}))
    end
  end

  defp undeclared(%Binding{declarations: declarations, commit: commit}, kind, type) do
    cond do
      not Declarations.names?(declarations, {:principal, kind}) ->
        verdict(commit, :deny, :subject_kind_unknown, %{subject_kind: kind})

      not Declarations.names?(declarations, {:resource, type}) ->
        verdict(commit, :deny, :no_rule_matched, %{resource_type: type})

      true ->
        nil
    end
  end

  defp asked(binding, subject, action, type, resource, context) do
    with {:ok, principal} <- Values.principal(binding, subject, context),
         {:ok, by_id} <- Values.resources(binding, subject, type, [resource], context) do
      {:ok, Request.check(subject, action, principal, [{resource, values(by_id, resource)}])}
    end
  end

  defp answered(%Binding{commit: commit}, body, answered, action, {type, id} = resource) do
    with {:ok, effects} <- effects(answered, action) do
      case Map.get(effects, key(resource)) do
        {"EFFECT_ALLOW", policy} ->
          {:ok, verdict(commit, :allow, :rule_allowed, %{policy: policy, request_id: body.requestId})}

        {_effect, policy} ->
          {:ok, verdict(commit, :deny, :no_rule_matched, %{policy: policy, request_id: body.requestId})}

        nil ->
          {:error, "the Cerbos server answered nothing about #{type} #{id} in request #{body.requestId}"}
      end
    end
  end

  defp compiled(%Binding{commit: commit} = binding, body, subject, action, type, context, filter) do
    meta = %{plan: shape(filter), request_id: body.requestId}

    case Plan.compile(plan(binding, subject, action, type, context, filter)) do
      {:ok, rule} -> {:ok, {rule, verdict(commit, :allow, :rule_allowed, meta)}}
      :denied -> {:ok, {dynamic([_row], false), verdict(commit, :deny, :no_rule_matched, meta)}}
      {:error, text} -> {:error, text}
    end
  end

  defp plan(%Binding{declarations: declarations} = binding, subject, action, type, context, filter) do
    {schema, key} = Binding.schema_and_key(binding, {:resource, type})

    %Plan{
      subject: subject,
      action: action,
      context: context,
      plan: filter,
      declarations: declarations,
      type: type,
      schema: schema,
      key: key
    }
  end

  defp shape(%{"kind" => "KIND_ALWAYS_ALLOWED"}), do: :always_allowed
  defp shape(%{"kind" => "KIND_ALWAYS_DENIED"}), do: :always_denied
  defp shape(_other), do: :conditional

  defp matched(result, action) do
    case result["meta"]["actions"][action]["matchedPolicy"] do
      "NO_MATCH" -> nil
      policy -> policy
    end
  end

  # Keyed by kind and id, because that is how the answer names a resource.
  defp effects(%{"results" => results}, action) when is_list(results) do
    name = Atom.to_string(action)
    {:ok, Map.new(results, &{resource_key(&1), {effect(&1, name), matched(&1, name)}})}
  end

  defp effects(other, _action) do
    {:error, "the Cerbos server answered no results: " <> String.slice(inspect(other), 0, 200)}
  end

  defp resource_key(result), do: {result["resource"]["kind"], result["resource"]["id"]}

  defp effect(result, action), do: result["actions"][action]

  defp values(by_id, {_type, id}), do: Map.get(by_id, to_string(id), %{})

  defp key({type, id}), do: {Atom.to_string(type), to_string(id)}

  defp verdict(commit, effect, reason, meta) do
    %Verdict{effect: effect, reason: reason, policy_version: commit, meta: meta}
  end
end
