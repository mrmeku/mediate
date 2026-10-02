defmodule Mediate.Rbac.Facts do
  @moduledoc """
  The fact check: every column a policy's rules read is a declared fact.
  `check/1` builds the plan of every protected schema for every action the
  role table names, and applies it to the schema. Then it walks the query
  the plan became, subqueries among them, and collects every field
  reference by source schema. A column counts as declared in one of these
  cases:

  - the schema's `fact` names it as the column, the subject, or the
    resource
  - the schema's `grant` names it as the subject, the resource, or an
    attribute
  - it is the primary key
  - it is the foreign key of a relation some protected schema covers,
    through the closure of what the covered schemas cover in turn

  The walk cannot enter a fragment, so a fragment fails as the finding
  `{:fragment, text}`.
  """

  import Ecto.Query, only: [where: 2]

  alias Mediate.Rbac.Infrastructure.Plan
  alias Mediate.Rbac.Policy
  alias Mediate.Rbac.Policy.Resource
  alias Mediate.Schema
  alias Mediate.Schema.Fact
  alias Mediate.Schema.Grant

  @typedoc "An undeclared read: the schema and the column, or a fragment's text."
  @type finding :: {module(), atom()} | {:fragment, String.t()}

  @doc "Ok, or the undeclared reads, sorted and without repeats."
  @spec check(Policy.t()) :: :ok | {:error, [finding()]}
  def check(policy) when is_atom(policy) do
    case undeclared(policy) do
      [] -> :ok
      findings -> {:error, findings}
    end
  end

  @doc "`check/1`, and it raises with every finding in the message."
  @spec check!(Policy.t()) :: :ok
  def check!(policy) when is_atom(policy) do
    case check(policy) do
      :ok -> :ok
      {:error, findings} -> raise ArgumentError, "#{inspect(policy)} reads undeclared columns: #{describe(findings)}"
    end
  end

  @doc "Every undeclared read across the policy's rules."
  @spec undeclared(Policy.t()) :: [finding()]
  def undeclared(policy) when is_atom(policy) do
    covered = covered(policy)

    policy
    |> reads()
    |> Enum.reject(&declared?(&1, covered))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Every read the policy's rules make, as findings, before the removal of the declared ones."
  @spec reads(Policy.t()) :: [finding()]
  def reads(policy) when is_atom(policy) do
    subject = {:user, "facts"}
    context = %{now: DateTime.from_unix!(0)}

    for %Resource{schema: schema} <- Policy.resources(policy),
        action <- Policy.actions(policy),
        {:ok, %Plan{} = plan} <- [Plan.build(policy, subject, action, Schema.resource_type_of(schema), context)],
        read <- walk_query(where(schema, ^Plan.dynamic(plan))),
        do: read
  end

  defp describe(findings) do
    Enum.map_join(findings, ", ", fn
      {:fragment, text} -> "fragment #{inspect(text)}"
      {schema, column} -> "#{column} of #{inspect(schema)}"
    end)
  end

  defp declared?({:fragment, _text}, _covered), do: false
  defp declared?({nil, _column}, _covered), do: true
  defp declared?({schema, column}, covered), do: column in own_declarations(schema) or {schema, column} in covered

  defp covered(policy) do
    for %Resource{schema: root} <- Policy.resources(policy),
        schema <- closure([root], []),
        name <- Schema.covers_of(schema),
        {held_by, key} = foreign_key(schema.__schema__(:association, name)),
        held_by != nil,
        do: {held_by, key}
  end

  defp closure([], seen), do: Enum.reverse(seen)

  defp closure([schema | rest], seen) do
    if schema in seen do
      closure(rest, seen)
    else
      next = for name <- Schema.covers_of(schema), related = related(schema, name), related != nil, do: related
      closure(rest ++ next, [schema | seen])
    end
  end

  defp related(schema, name) do
    case schema.__schema__(:association, name) do
      %{related: related} -> related
      _through -> nil
    end
  end

  defp own_declarations(schema) do
    facts =
      for %Fact{column: column, subject: subject, resource: resource} <- Schema.facts_of(schema),
          do: [column, subject, resource]

    grant =
      case Schema.grant_of(schema) do
        %Grant{subject: subject, resource: resource, attributes: attributes} -> [subject, resource | attributes]
        nil -> []
      end

    Enum.reject(schema.__schema__(:primary_key) ++ List.flatten(facts) ++ grant, &is_nil/1)
  end

  defp foreign_key(%Ecto.Association.Has{related: related, related_key: key}), do: {related, key}
  defp foreign_key(%Ecto.Association.BelongsTo{owner: owner, owner_key: key}), do: {owner, key}
  defp foreign_key(_other), do: {nil, nil}

  defp walk_query(%Ecto.Query{} = query) do
    sources = [source_schema(query.from.source) | Enum.map(query.joins, &source_schema(&1.source))]
    Enum.flat_map(exprs(query), &walk_expr(&1.expr, &1.subqueries || [], sources))
  end

  defp exprs(%Ecto.Query{} = query) do
    clauses = query.wheres ++ query.havings ++ query.order_bys ++ query.group_bys
    joins = Enum.map(query.joins, &%{expr: &1.on.expr, subqueries: Map.get(&1.on, :subqueries)})
    List.wrap(query.select) ++ clauses ++ joins
  end

  defp source_schema({_table, schema}) when is_atom(schema), do: schema
  defp source_schema(_subquery_or_fragment), do: nil

  defp walk_expr({{:., _dot, [{:&, _binding, [index]}, field]}, _meta, []}, _subqueries, sources) do
    [{Enum.at(sources, index), field}]
  end

  defp walk_expr({:subquery, index}, subqueries, _sources) do
    %Ecto.SubQuery{query: query} = Enum.at(subqueries, index)
    walk_query(query)
  end

  defp walk_expr({:fragment, _meta, parts}, _subqueries, _sources) do
    [{:fragment, Enum.map_join(parts, "", &fragment_part/1)}]
  end

  defp walk_expr({_op, _meta, args}, subqueries, sources) when is_list(args) do
    Enum.flat_map(args, &walk_expr(&1, subqueries, sources))
  end

  defp walk_expr({left, right}, subqueries, sources) do
    walk_expr(left, subqueries, sources) ++ walk_expr(right, subqueries, sources)
  end

  defp walk_expr(list, subqueries, sources) when is_list(list) do
    Enum.flat_map(list, &walk_expr(&1, subqueries, sources))
  end

  defp walk_expr(%Ecto.Query.Tagged{value: value}, subqueries, sources), do: walk_expr(value, subqueries, sources)
  defp walk_expr(%{} = map, subqueries, sources), do: walk_expr(Map.to_list(map), subqueries, sources)
  defp walk_expr(_literal, _subqueries, _sources), do: []

  defp fragment_part({:raw, text}), do: text
  defp fragment_part({:expr, _expression}), do: "?"
end
