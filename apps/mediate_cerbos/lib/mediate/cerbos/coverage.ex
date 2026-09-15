defmodule Mediate.Cerbos.Coverage do
  @moduledoc """
  Declared-fact coverage for a compiled query plan: every column the query
  reads is a declared fact. `docs/conformance.md` §2 names this check as
  `au12-07`.

  A plan comes from the sidecar and becomes a query here. This is the one
  place where what a policy reads turns into what the database reads. So
  the check walks the query and its subqueries, and collects every field
  reference by the schema of the source it names. Then it sets each
  reference against the declarations of that schema. The walk cannot read
  a fragment, so a fragment is the finding `{:fragment, text}`.

  A column counts as declared in four cases:

  - the schema's `fact` names it as the column, the subject, or the object
  - the schema's `relationship` names it as the subject, the object, or an
    attribute
  - it is the primary key
  - it is the foreign key of a relation a declared schema carries, through
    the closure of what the carried schemas carry in turn

  The closure starts from the schemas the attribute declarations name,
  because those are the schemas this adapter reads at all. A read of a
  column no declaration covers is a fact that never went through the seam.
  That is what this check exists to catch.

  The walk covers whole every query it reaches:

  - the query a subquery operand carries
  - the query behind a source that is no table
  - each query a union or an intersection combines with

  A plan compiles a subquery attribute to a source of that kind. A walk
  that stopped at the source reports nothing about the very query the
  declaration named.
  """

  alias Mediate.Cerbos.Attributes
  alias Mediate.Schema
  alias Mediate.Schema.Fact
  alias Mediate.Schema.Relationship

  @typedoc "An undeclared read: the schema and the column, or a fragment's text."
  @type finding :: {module(), atom()} | {:fragment, String.t()}

  @doc "Ok, or the undeclared reads of the query, sorted and without repeats."
  @spec check(Attributes.t(), Ecto.Queryable.t()) :: :ok | {:error, [finding()]}
  def check(attributes, queryable) when is_atom(attributes) do
    case undeclared(attributes, queryable) do
      [] -> :ok
      findings -> {:error, findings}
    end
  end

  @doc "`check/2`, but it raises, with the findings named."
  @spec check!(Attributes.t(), Ecto.Queryable.t()) :: :ok
  def check!(attributes, queryable) when is_atom(attributes) do
    case check(attributes, queryable) do
      :ok ->
        :ok

      {:error, findings} ->
        raise ArgumentError, "the query reads columns #{inspect(attributes)} does not declare: #{describe(findings)}"
    end
  end

  @doc "Every undeclared read the query makes."
  @spec undeclared(Attributes.t(), Ecto.Queryable.t()) :: [finding()]
  def undeclared(attributes, queryable) when is_atom(attributes) do
    carried = carried(attributes)

    queryable
    |> reads()
    |> Enum.reject(&declared?(&1, carried))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Every read the query makes, as findings, before the removal of the declared ones."
  @spec reads(Ecto.Queryable.t()) :: [finding()]
  def reads(queryable), do: walk_query(Ecto.Queryable.to_query(queryable))

  defp describe(findings) do
    Enum.map_join(findings, ", ", fn
      {:fragment, text} -> "fragment #{inspect(text)}"
      {schema, column} -> "#{column} of #{inspect(schema)}"
    end)
  end

  defp declared?({:fragment, _text}, _carried), do: false
  defp declared?({nil, _column}, _carried), do: true
  defp declared?({schema, column}, carried), do: column in own_declarations(schema) or {schema, column} in carried

  defp carried(attributes) do
    roots = for {_side, _kind, schema} <- Attributes.kinds(attributes), do: schema

    for schema <- closure(roots, []),
        name <- Schema.carries_of(schema),
        {held_by, key} = foreign_key(schema.__schema__(:association, name)),
        held_by != nil,
        do: {held_by, key}
  end

  defp closure([], seen), do: Enum.reverse(seen)

  defp closure([schema | rest], seen) do
    if schema in seen do
      closure(rest, seen)
    else
      next = for name <- Schema.carries_of(schema), related = related(schema, name), related != nil, do: related
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
      for %Fact{column: column, subject: subject, object: object} <- Schema.facts_of(schema),
          do: [column, subject, object]

    relationship =
      case Schema.relationship_of(schema) do
        %Relationship{subject: subject, object: object, attributes: attributes} -> [subject, object | attributes]
        nil -> []
      end

    Enum.reject(schema.__schema__(:primary_key) ++ List.flatten(facts) ++ relationship, &is_nil/1)
  end

  defp foreign_key(%Ecto.Association.Has{related: related, related_key: key}), do: {related, key}
  defp foreign_key(%Ecto.Association.BelongsTo{owner: owner, owner_key: key}), do: {owner, key}
  defp foreign_key(_other), do: {nil, nil}

  defp walk_query(%Ecto.Query{} = query) do
    sources = [query.from.source | Enum.map(query.joins, & &1.source)]

    walk_exprs(query, sources) ++ Enum.flat_map(sources, &walk_source/1) ++ walk_combinations(query)
  end

  defp walk_exprs(%Ecto.Query{} = query, sources) do
    schemas = Enum.map(sources, &source_schema/1)

    Enum.flat_map(exprs(query), &walk_expr(&1.expr, &1.subqueries || [], schemas))
  end

  defp walk_source(%Ecto.SubQuery{query: query}), do: walk_query(query)
  defp walk_source(_table_or_fragment), do: []

  defp walk_combinations(%Ecto.Query{combinations: combinations}) do
    Enum.flat_map(combinations, fn {_operator, query} -> walk_query(query) end)
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
