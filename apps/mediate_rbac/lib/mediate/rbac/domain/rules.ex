defmodule Mediate.Rbac.Domain.Rules do
  @moduledoc false
  # The rules of a policy. `Mediate.Rbac.Policy` generates one call of
  # `resource/3` per protected schema, with a `grant/4` or `predicate/4`
  # per rule, inside the function the policy module answers `resources/1`
  # with. Each raises on a declaration the schemas cannot back, so a bad
  # policy fails at its first read and not on a request.
  # `Mediate.Rbac.Policy` says why the check runs at read time and not at
  # compile time.
  #
  # Every message names the policy module first, so the reader opens the
  # right file, then the rule by name, the value found, and what to do.

  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Policy.Resource
  alias Mediate.Rbac.Policy.Rule
  alias Mediate.Schema
  alias Mediate.Schema.Grant

  @grant_schema NimbleOptions.new!(
                  on: [type: :atom, doc: "The protected column the grant's resource column names."],
                  role_column: [type: :atom, doc: "The grant column that holds the role."],
                  role: [type: :atom, doc: "The role every row holds, when there is no role column."],
                  through: [
                    type: {:list, {:custom, __MODULE__, :hop, []}},
                    default: [],
                    doc:
                      "The hops from the protected row outward, each `{schema, column}` or `{schema, column, where: fun}`."
                  ]
                )

  @predicate_schema NimbleOptions.new!(
                      actions: [
                        type: {:list, :atom},
                        doc: "The actions the predicate applies to, or every action when absent."
                      ]
                    )

  @doc "The protected schema of a resource type in a policy, or nil."
  @spec resource_of(Policy.t(), atom()) :: Resource.t() | nil
  def resource_of(policy, type) when is_atom(policy) and is_atom(type) do
    Enum.find(Policy.resources(policy), &(Schema.resource_type_of(&1.schema) == type))
  end

  @doc "A protected schema and its rules. The schema must declare a resource type."
  @spec resource(Policy.t(), module(), [Rule.t()]) :: Resource.t()
  def resource(policy, schema, rules) when is_atom(policy) and is_atom(schema) and is_list(rules) do
    if !Schema.resource_type_of(schema) do
      raise ArgumentError,
            "#{inspect(policy)}: resource #{inspect(schema)} declares no resource type; " <>
              "give the schema `resource_type/1`"
    end

    %Resource{schema: schema, rules: rules}
  end

  @doc "A grant rule. The grant schema must declare a grant whose role column the rule can name."
  @spec grant(Policy.t(), atom(), module(), keyword()) :: Rule.t()
  def grant(policy, name, grant, options)
      when is_atom(policy) and is_atom(name) and is_atom(grant) and is_list(options) do
    validated = NimbleOptions.validate!(options, @grant_schema)

    role_column!(policy, name, grant, Schema.grant_of(grant), validated)

    %Rule{
      name: name,
      kind: :grant,
      grant: grant,
      on: validated[:on],
      role_column: validated[:role_column],
      role: validated[:role],
      through: validated[:through]
    }
  end

  @doc "A predicate rule. The function must be a capture of a named function."
  @spec predicate(Policy.t(), atom(), Rule.predicate(), keyword()) :: Rule.t()
  def predicate(policy, name, fun, options)
      when is_atom(policy) and is_atom(name) and is_function(fun, 2) and is_list(options) do
    validated = NimbleOptions.validate!(options, @predicate_schema)

    if named?(fun) do
      %Rule{name: name, kind: :predicate, predicate: fun, actions: validated[:actions]}
    else
      raise ArgumentError,
            "#{inspect(policy)}: predicate #{inspect(name)} is an anonymous function; " <>
              "give a capture of a named function, as `&MyApp.Predicates.cleared/2`"
    end
  end

  @doc "One hop of a grant rule's `through:` list, as `NimbleOptions` validates it."
  @spec hop(term()) :: {:ok, Rule.hop()} | {:error, String.t()}
  def hop({schema, column}) when is_atom(schema) and is_atom(column), do: {:ok, {schema, column, []}}

  def hop({schema, column, where: fun}) when is_atom(schema) and is_atom(column) and is_function(fun, 0) do
    if named?(fun) do
      {:ok, {schema, column, where: fun}}
    else
      {:error, "hop #{inspect(schema)} has an anonymous where:; give a capture of a named function of no arguments"}
    end
  end

  def hop(other) do
    {:error, "hop #{inspect(other)} must be {schema, column} or {schema, column, where: capture}"}
  end

  defp named?(fun), do: match?({:type, :external}, Function.info(fun, :type))

  defp role_column!(policy, name, grant, nil, _validated) do
    raise ArgumentError,
          "#{inspect(policy)}: grant rule #{inspect(name)} reads #{inspect(grant)}, which declares no grant; " <>
            "give the schema `grant/1`"
  end

  defp role_column!(_policy, _name, _grant, %Grant{attributes: [_role]}, _validated), do: :ok

  defp role_column!(policy, name, grant, %Grant{attributes: attributes}, validated) do
    if validated[:role_column] || validated[:role] do
      :ok
    else
      raise ArgumentError,
            "#{inspect(policy)}: grant rule #{inspect(name)} must name its role column; " <>
              "#{inspect(grant)} declares the attributes #{Enum.join(attributes, ", ")}; " <>
              "give role_column:, or a fixed role with role:"
    end
  end
end
