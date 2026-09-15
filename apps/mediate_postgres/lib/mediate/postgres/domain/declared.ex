defmodule Mediate.Postgres.Domain.Declared do
  @moduledoc false
  # Which reads a declaration covers. The catalog supplies the columns the
  # policies name. This module decides what counts as declared against the
  # bound schemas alone, so it belongs in `domain/`.
  # `Mediate.Postgres.Coverage` lists what counts as declared.

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Coverage
  alias Mediate.Schema
  alias Mediate.Schema.Fact
  alias Mediate.Schema.Relationship

  @doc "The undeclared reads among those columns, sorted and without repeats."
  @spec findings(Binding.t(), [{String.t(), String.t()}]) :: [Coverage.finding()]
  def findings(%Binding{} = binding, columns) when is_list(columns) do
    carried = carried(binding)

    columns
    |> Enum.map(&finding(binding, carried, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "The findings as one line, for the raise."
  @spec describe([Coverage.finding()]) :: String.t()
  def describe(findings) when is_list(findings) do
    Enum.map_join(findings, ", ", fn
      {:table, table} -> "table #{table}"
      {schema, column} -> "#{column} of #{inspect(schema)}"
    end)
  end

  defp finding(binding, carried, {table, column}) do
    schema = Binding.schema_of(binding, table)

    cond do
      is_nil(schema) -> {:table, table}
      declared?(schema, column, carried) -> nil
      true -> {schema, column}
    end
  end

  defp declared?(schema, column, carried) do
    column in own_declarations(schema) or {schema, column} in carried
  end

  defp carried(%Binding{schemas: schemas}) do
    for schema <- closure(schemas, []),
        name <- Schema.carries_of(schema),
        {held_by, key} = foreign_key(schema.__schema__(:association, name)),
        held_by != nil,
        do: {held_by, Atom.to_string(key)}
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
    declared = schema.__schema__(:primary_key) ++ fact_columns(schema) ++ relationship_columns(schema)

    declared
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Atom.to_string/1)
  end

  defp fact_columns(schema) do
    facts =
      for %Fact{column: column, subject: subject, object: object} <- Schema.facts_of(schema),
          do: [column, subject, object]

    List.flatten(facts)
  end

  defp relationship_columns(schema) do
    case Schema.relationship_of(schema) do
      %Relationship{subject: subject, object: object, attributes: attributes} -> [subject, object | attributes]
      nil -> []
    end
  end

  defp foreign_key(%Ecto.Association.Has{related: related, related_key: key}), do: {related, key}
  defp foreign_key(%Ecto.Association.BelongsTo{owner: owner, owner_key: key}), do: {owner, key}
  defp foreign_key(_other), do: {nil, nil}
end
