defmodule Mediate.Postgres.Domain.Coverage do
  @moduledoc false
  # Which reads a declaration covers. The catalog supplies the columns the
  # rules read. This module decides what counts as declared against the
  # bound schemas alone, so it is domain. `Mediate.Postgres.Facts` lists
  # what counts as declared.

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Facts
  alias Mediate.Schema
  alias Mediate.Schema.Fact
  alias Mediate.Schema.Grant

  @doc "The undeclared reads among those columns, sorted and without repeats."
  @spec undeclared(Binding.t(), [{String.t(), String.t()}]) :: [Facts.finding()]
  def undeclared(%Binding{} = binding, reads) when is_list(reads) do
    covered = covered(binding)

    reads
    |> Enum.map(&finding(binding, covered, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "The findings as one line, for the raise."
  @spec describe([Facts.finding()]) :: String.t()
  def describe(findings) when is_list(findings) do
    Enum.map_join(findings, ", ", fn
      {:table, table} -> "table #{table}"
      {schema, column} -> "#{column} of #{inspect(schema)}"
    end)
  end

  defp finding(binding, covered, {table, column}) do
    schema = Binding.schema_of(binding, table)

    cond do
      is_nil(schema) -> {:table, table}
      declared?(schema, column, covered) -> nil
      true -> {schema, column}
    end
  end

  defp declared?(schema, column, covered) do
    column in own_declarations(schema) or {schema, column} in covered
  end

  defp covered(%Binding{schemas: schemas}) do
    for schema <- closure(schemas, []),
        name <- Schema.covers_of(schema),
        {held_by, key} = foreign_key(schema.__schema__(:association, name)),
        held_by != nil,
        do: {held_by, Atom.to_string(key)}
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
    declared = schema.__schema__(:primary_key) ++ fact_columns(schema) ++ grant_columns(schema)

    declared
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Atom.to_string/1)
  end

  defp fact_columns(schema) do
    facts =
      for %Fact{column: column, subject: subject, resource: resource} <- Schema.facts_of(schema),
          do: [column, subject, resource]

    List.flatten(facts)
  end

  defp grant_columns(schema) do
    case Schema.grant_of(schema) do
      %Grant{subject: subject, resource: resource, attributes: attributes} -> [subject, resource | attributes]
      nil -> []
    end
  end

  defp foreign_key(%Ecto.Association.Has{related: related, related_key: key}), do: {related, key}
  defp foreign_key(%Ecto.Association.BelongsTo{owner: owner, owner_key: key}), do: {owner, key}
  defp foreign_key(_other), do: {nil, nil}
end
