defmodule Mediate.Cerbos.Infrastructure.Values do
  @moduledoc false
  # The values of the declared attributes, read through the bound repo as
  # the library. One query reads the columns of a block. One query per
  # subquery attribute reads its values, built from the subject and the
  # context the library stamped the request with.
  #
  # Every declared attribute goes to the server, whether or not the row
  # holds it. A column with nothing in it goes as null, and a subquery that
  # selected nothing goes as the empty list. An absent attribute makes the
  # server record an evaluation error against the request, and not read the
  # attribute as empty. That record carries a fault where the answer is
  # sound.
  #
  # Each value crosses to JSON through the codec. A plan compiled from the
  # same policy compares a column against that same form.
  #
  # This module catches nothing a repo raises. The library turns any
  # exception an engine raises into the engine error that denies. So this
  # package names no driver's error, and a driver it does not carry needs
  # no clause of its own.
  #
  # The context facts go with the subject's own attributes, under the name
  # `Mediate.Cerbos.Attribute.reserved_name/0`. `context/2` builds them.
  # They hold the moment the library stamped the request with, always. They
  # hold each fact a `context` block declared, whether the caller supplied
  # it or not. The codec cuts every moment among them to the second, and
  # says why.

  import Ecto.Query, only: [from: 2, subquery: 1]

  alias Mediate.Cerbos.Attribute
  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Declarations
  alias Mediate.Cerbos.Domain.Codec

  @exemption {:exempt, :library}

  @doc "The subject's own attributes, from the block of its kind, with the context facts beside them."
  @spec principal(Binding.t(), Mediate.subject(), Mediate.context()) :: {:ok, Attribute.values()} | {:error, String.t()}
  def principal(%Binding{} = binding, {kind, id} = subject, %{now: _now} = context) do
    with {:ok, by_id} <- by_ids(binding, subject, {:principal, kind}, [id], context) do
      own = Map.fetch!(by_id, to_string(id))
      {:ok, Map.put(own, Attribute.reserved_name(), context(binding, context))}
    end
  end

  @doc "The context facts: the moment the library stamped the request with, and each declared fact."
  @spec context(Binding.t(), Mediate.context()) :: Attribute.values()
  def context(%Binding{declarations: declarations}, %{now: _now} = context) do
    declared = Map.new(Declarations.facts(declarations), &{&1, Codec.to_second(Map.get(context, &1))})
    Map.put(declared, :now, Codec.to_second(context.now))
  end

  @doc "The attributes of each resource of one type, by the resource's id as text."
  @spec resources(Binding.t(), Mediate.subject(), atom(), [Mediate.resource()], Mediate.context()) ::
          {:ok, %{String.t() => Attribute.values()}} | {:error, String.t()}
  def resources(%Binding{} = binding, {_kind, _account} = subject, type, resources, %{now: _now} = context)
      when is_atom(type) and is_list(resources) do
    by_ids(binding, subject, {:resource, type}, Enum.map(resources, &elem(&1, 1)), context)
  end

  @doc "The attributes of the ids of one block, every declared name present."
  @spec by_ids(Binding.t(), Mediate.subject(), Declarations.block(), [term()], Mediate.context()) ::
          {:ok, %{String.t() => Attribute.values()}} | {:error, String.t()}
  def by_ids(%Binding{} = binding, {_kind, _account} = subject, {side, name} = block, ids, %{now: _now} = context)
      when is_list(ids) do
    declarations = binding.declarations

    if Declarations.names?(declarations, block) do
      declared = Declarations.attributes_of(declarations, block)
      from_columns = columns(binding, block, ids, declared)
      from_subqueries = subqueries(binding, subject, context, ids, declared)
      absent = absent(declared)
      {:ok, Map.new(ids, &{to_string(&1), found(absent, from_columns, from_subqueries, to_string(&1))})}
    else
      {:error, "#{inspect(declarations)} declares no #{side} #{inspect(name)}"}
    end
  end

  defp found(absent, from_columns, from_subqueries, key) do
    absent
    |> Map.merge(Map.get(from_columns, key, %{}))
    |> Map.merge(Map.get(from_subqueries, key, %{}))
  end

  defp absent(declared) do
    Map.new(declared, fn
      %Attribute{name: name, source: {:column, _column}} -> {name, nil}
      %Attribute{name: name, source: {:subquery, _fun}} -> {name, []}
    end)
  end

  defp columns(binding, block, ids, declared) do
    case Enum.filter(declared, &Attribute.column?/1) do
      [] -> %{}
      attributes -> selected(binding, block, ids, attributes)
    end
  end

  defp selected(binding, block, ids, attributes) do
    {schema, key} = Binding.schema_and_key(binding, block)
    names = Enum.map(attributes, fn %Attribute{source: {:column, column}} -> column end)
    query = from(row in schema, where: field(row, ^key) in ^ids, select: {field(row, ^key), map(row, ^names)})
    rows = all(binding.repo, query)

    Map.new(rows, fn {id, values} -> {to_string(id), named(attributes, values)} end)
  end

  defp named(attributes, values) do
    Map.new(attributes, fn %Attribute{name: name, source: {:column, column}} -> {name, Codec.encode(values[column])} end)
  end

  defp subqueries(binding, subject, context, ids, declared) do
    declared
    |> Enum.reject(&Attribute.column?/1)
    |> Enum.reduce(%{}, fn attribute, acc ->
      gathered(acc, attribute.name, read_subquery(binding, subject, context, ids, attribute))
    end)
  end

  defp read_subquery(binding, subject, context, ids, %Attribute{source: {:subquery, fun}}) do
    query = from(row in subquery(fun.(subject, context)), where: row.id in ^ids, select: {row.id, row.value})
    all(binding.repo, query)
  end

  defp gathered(acc, name, rows) do
    rows
    |> Enum.group_by(fn {id, _value} -> to_string(id) end, fn {_id, value} -> Codec.encode(value) end)
    |> Enum.reduce(acc, fn {key, values}, into ->
      Map.update(into, key, %{name => values}, &Map.put(&1, name, values))
    end)
  end

  defp all(repo, query), do: repo.all(query, authorized_by: @exemption)
end
