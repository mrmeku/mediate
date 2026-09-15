defmodule Mediate.Domain.Matching do
  @moduledoc false
  # The seam applies three rules to one query:
  #
  # 1. The root source decides the query. A protected root needs a decision
  #    that names its object type, a carried admission, or an exemption.
  # 2. A preload or association query is a query of its own, with the
  #    association's schema as root. It passes when the parent's decision
  #    carries the association.
  # 3. Every other protected source in the query, a joined schema or a
  #    subquery's root, must pass the same way.
  #
  # A protected schema is one that declares an object type. A source
  # without a schema, a table name or a fragment, passes without a check.
  #
  # A refusal names the module that made the call. Only the running process
  # knows that module, so the caller arrives as a function the seam
  # supplies. A judgement that passes never calls it.

  alias Ecto.Query.JoinExpr
  alias Mediate.Domain.Mediation
  alias Mediate.Schema

  @typedoc "The function that reads the module that made the call, where a refusal has to name it."
  @type caller :: (-> module() | :any)

  @doc "Judge a query under a mediation. It returns `:ok` or raises `Mediate.Error`."
  @spec judge(Ecto.Query.t(), Mediation.t() | nil, caller()) :: :ok
  def judge(%Ecto.Query{} = query, mediation, caller) when is_function(caller, 0) do
    root = admit_source(query.from.source, mediation, caller)
    _sources = admit_joins(query.joins, %{0 => root}, mediation, caller)
    :ok
  end

  @doc "Admit one schema under a mediation. It returns `:ok` or raises `Mediate.Error`."
  @spec admit(module() | nil, Mediation.t() | nil, caller()) :: :ok
  def admit(schema, mediation, caller) when is_function(caller, 0) do
    if admitted?(schema, mediation), do: :ok, else: refuse(schema, mediation, caller)
  end

  @doc "Whether a schema passes under a mediation."
  @spec admitted?(module() | nil, Mediation.t() | nil) :: boolean()
  def admitted?(schema, mediation) do
    case Schema.object_type_of(schema) do
      nil -> true
      type -> Mediation.exempt?(mediation) or Mediation.object_type(mediation) == type or schema in carried(mediation)
    end
  end

  defp carried(%Mediation{carried: carried}), do: carried
  defp carried(nil), do: []

  defp admit_source({_table, schema}, mediation, caller) do
    :ok = admit(schema, mediation, caller)
    schema
  end

  defp admit_source(%Ecto.SubQuery{query: inner}, mediation, caller) do
    :ok = judge(inner, mediation, caller)
    root_schema(inner)
  end

  defp admit_source(_other, _mediation, _caller), do: nil

  # Every join's source, keyed by binding index. Each join passes the check as the fold meets it.
  defp admit_joins(joins, sources, mediation, caller) do
    joins
    |> Enum.with_index(1)
    |> Enum.reduce(sources, fn {join, index}, sources ->
      Map.put(sources, index, admit_join(join, sources, mediation, caller))
    end)
  end

  defp admit_join(%JoinExpr{source: nil, assoc: {index, field}}, sources, mediation, caller) do
    case Map.get(sources, index) do
      nil ->
        nil

      parent ->
        schema = Mediation.related(parent, field)
        :ok = admit(schema, mediation, caller)
        schema
    end
  end

  defp admit_join(%JoinExpr{source: source}, _sources, mediation, caller), do: admit_source(source, mediation, caller)

  defp root_schema(%Ecto.Query{from: %{source: {_table, schema}}}), do: schema
  defp root_schema(%Ecto.Query{from: %{source: %Ecto.SubQuery{query: inner}}}), do: root_schema(inner)
  defp root_schema(_query), do: nil

  defp refuse(schema, mediation, caller) do
    {name, arity} = call(mediation)

    raise Mediation.unmediated(
            function: name,
            arity: arity,
            schema: schema,
            object_type: Mediation.object_type(mediation),
            caller: caller.()
          )
  end

  defp call(%Mediation{call: call}), do: call
  defp call(nil), do: {:prepare_query, 3}
end
