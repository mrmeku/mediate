defmodule Mediate.Rbac.Infrastructure.Plan do
  @moduledoc false
  # A protected schema's plan for one subject and action, built from the
  # policy's rules as `dynamic` expressions over the protected row:
  #
  # - each grant rule is a membership test against a subquery of its grant
  #   schema. One subquery per hop wraps it when the rule runs `through`
  #   other schemas
  # - each predicate rule that applies to the action is the function's
  #   result
  # - the whole is any grant and every predicate
  #
  # A build runs no query. `dynamic/1` is the expression `filter` returns,
  # and the rule map is what `Decide` selects for the row asked about.
  # One build serves both, so a filtered query and an authorized row agree.

  import Ecto.Query, only: [dynamic: 2, from: 2]

  alias Mediate.Rbac.Domain.Rules
  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Policy.Resource
  alias Mediate.Rbac.Policy.Rule
  alias Mediate.Rbac.Version
  alias Mediate.Schema
  alias Mediate.Schema.Grant
  alias Mediate.Verdict

  @enforce_keys [:policy, :schema, :action, :roles, :grants, :predicates, :policy_version]
  defstruct @enforce_keys

  @typedoc "A rule name and its expression over the protected row."
  @type rule :: {atom(), Ecto.Query.dynamic_expr()}

  @type t :: %__MODULE__{
          policy: Policy.t(),
          schema: module(),
          action: atom(),
          roles: [atom()],
          grants: [rule()],
          predicates: [rule()],
          policy_version: String.t()
        }

  @doc """
  Builds the plan. Answers a deny verdict when the policy has no resource
  of the type, or when no role permits the action. Answers
  `{:error, text}` when a predicate returned neither a `dynamic` nor a
  boolean.
  """
  @spec build(Policy.t(), Mediate.subject(), atom(), atom(), Mediate.context()) ::
          {:ok, t()} | {:error, Verdict.t() | String.t()}
  def build(policy, {_kind, _account} = subject, action, type, %{now: _now} = context)
      when is_atom(policy) and is_atom(action) and is_atom(type) do
    policy_version = Version.policy_version(policy)

    with {:ok, %Resource{} = resource} <- resource(policy, type, policy_version),
         {:ok, roles} <- roles(policy, action, policy_version),
         {:ok, predicates} <- predicates(resource, action, subject, context) do
      {:ok, new(policy, resource, action, roles, grants(resource, subject, roles), predicates, policy_version)}
    end
  end

  @doc "The whole plan: any grant and every predicate."
  @spec dynamic(t()) :: Ecto.Query.dynamic_expr()
  def dynamic(%__MODULE__{grants: grants, predicates: predicates}) do
    any = Enum.reduce(grants, dynamic([_row], false), fn {_name, grant}, acc -> dynamic([row], ^acc or ^grant) end)
    Enum.reduce(predicates, any, fn {_name, predicate}, acc -> dynamic([row], ^acc and ^predicate) end)
  end

  @doc "The plan's rules by name, for a select."
  @spec rules(t()) :: %{atom() => Ecto.Query.dynamic_expr()}
  def rules(%__MODULE__{grants: grants, predicates: predicates}), do: Map.new(grants ++ predicates)

  @doc "The verdict a filter carries: allowed by the plan's rules, by name."
  @spec verdict(t()) :: Verdict.t()
  def verdict(%__MODULE__{grants: grants, predicates: predicates, policy_version: policy_version}) do
    names = Enum.map_join(grants ++ predicates, ", ", fn {name, _expression} -> Atom.to_string(name) end)
    %Verdict{effect: :allow, reason: :rule_allowed, policy_version: policy_version, meta: %{rule: names}}
  end

  @doc "The deny verdict for a reason, with what `Decide` can name on `meta`."
  @spec deny(Verdict.reason(), String.t(), map()) :: Verdict.t()
  def deny(reason, policy_version, meta \\ %{}) when is_atom(reason) and is_binary(policy_version) and is_map(meta) do
    %Verdict{effect: :deny, reason: reason, policy_version: policy_version, meta: meta}
  end

  @doc "The one column of a schema's primary key."
  @spec primary_key(module()) :: atom()
  def primary_key(schema) when is_atom(schema) do
    case schema.__schema__(:primary_key) do
      [key] -> key
      keys -> raise ArgumentError, "#{inspect(schema)} has the primary key #{inspect(keys)}; a rule needs one column"
    end
  end

  defp new(policy, %Resource{schema: schema}, action, roles, grants, predicates, policy_version) do
    %__MODULE__{
      policy: policy,
      schema: schema,
      action: action,
      roles: roles,
      grants: grants,
      predicates: predicates,
      policy_version: policy_version
    }
  end

  defp grants(%Resource{schema: schema, rules: rules}, subject, roles) do
    for %Rule{kind: :grant} = rule <- rules, do: {rule.name, grant(rule, schema, subject, roles)}
  end

  defp resource(policy, type, policy_version) do
    case Rules.resource_of(policy, type) do
      %Resource{} = resource -> {:ok, resource}
      nil -> {:error, deny(:no_rule_matched, policy_version)}
    end
  end

  defp roles(policy, action, policy_version) do
    case Policy.roles_for(policy, action) do
      [] -> {:error, deny(:action_unknown, policy_version)}
      roles -> {:ok, roles}
    end
  end

  defp predicates(%Resource{rules: rules}, action, subject, context) do
    step = fn rule, {:ok, acc} -> collect(predicate(rule, subject, context), rule.name, acc) end
    applicable = Enum.filter(rules, &applies?(&1, action))

    with {:ok, reversed} <- Enum.reduce_while(applicable, {:ok, []}, step) do
      {:ok, Enum.reverse(reversed)}
    end
  end

  defp applies?(%Rule{kind: :predicate, actions: nil}, _action), do: true
  defp applies?(%Rule{kind: :predicate, actions: actions}, action), do: action in actions
  defp applies?(%Rule{}, _action), do: false

  defp collect({:ok, expression}, name, acc), do: {:cont, {:ok, [{name, expression} | acc]}}
  defp collect({:error, text}, _name, _acc), do: {:halt, {:error, text}}

  defp predicate(%Rule{name: name, predicate: fun}, subject, context) do
    case fun.(subject, context) do
      %Ecto.Query.DynamicExpr{} = expression -> {:ok, expression}
      true -> {:ok, dynamic([_row], true)}
      false -> {:ok, dynamic([_row], false)}
      other -> {:error, "predicate #{name} returned #{inspect(other)}, not a dynamic or a boolean"}
    end
  end

  defp grant(%Rule{} = rule, schema, {_kind, subject_id}, roles) do
    on = rule.on || primary_key(schema)

    case members(rule, subject_id, roles) do
      nil -> dynamic([_row], false)
      members -> dynamic([row], field(row, ^on) in subquery(through(members, rule.through)))
    end
  end

  defp members(%Rule{grant: grant} = rule, subject_id, roles) do
    declared = Schema.grant_of(grant)

    case role_filter(rule, declared, roles) do
      :none -> nil
      :all -> named(grant, declared, subject_id)
      {:column, role_column} -> held(named(grant, declared, subject_id), role_column, roles)
    end
  end

  defp named(grant, %Grant{subject: subject_column, resource: resource_column}, subject_id) do
    from(r in grant, where: field(r, ^subject_column) == ^subject_id, select: field(r, ^resource_column))
  end

  # The rows that hold one of the roles the column can hold. A role the
  # column cannot hold never matches. Without the filter, a role table that
  # spans grant schemas with different role columns fails to cast the roles
  # another schema's column holds.
  defp held(%Ecto.Query{from: %{source: {_table, grant}}} = members, column, roles) do
    type = grant.__schema__(:type, column)
    held = Enum.filter(roles, &match?({:ok, _value}, Ecto.Type.cast(type, &1)))
    from(r in members, where: field(r, ^column) in ^held)
  end

  defp through(inner, hops) do
    Enum.reduce(Enum.reverse(hops), inner, fn {hop, column, options}, set ->
      key = primary_key(hop)
      query = from(h in hop, where: field(h, ^column) in subquery(set), select: field(h, ^key))

      case options[:where] do
        nil -> query
        filter -> from(h in query, where: ^filter.())
      end
    end)
  end

  defp role_filter(%Rule{role: role}, _declared, roles) when is_atom(role) and not is_nil(role) do
    if role in roles, do: :all, else: :none
  end

  defp role_filter(%Rule{role_column: column}, _declared, _roles) when is_atom(column) and not is_nil(column) do
    {:column, column}
  end

  defp role_filter(%Rule{}, %Grant{attributes: [role_column]}, _roles), do: {:column, role_column}
end
