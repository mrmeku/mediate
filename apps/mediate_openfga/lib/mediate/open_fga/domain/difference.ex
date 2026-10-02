defmodule Mediate.OpenFGA.Domain.Difference do
  @moduledoc false
  # The arithmetic of a pass. Given the tuples an object requires and the
  # tuples the store holds for it, what the pass tells the store.
  #
  # Nothing here reads an event or a row. `between/2` compares two lists
  # of tuples. That is why a pass that runs twice over the same object
  # writes nothing the second time. It is also why a marker that arrives
  # again costs a read and no write.
  #
  # The user, the relation, and the object are a tuple's triple, and its
  # condition is a value on it. So a tuple whose condition changed is the
  # same triple with another value: a delete and a write of that triple.
  # One call refuses a triple on both of its sides (OpenFGA 1.19.0). So
  # the write of such a triple goes in a later call than its delete.

  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.TupleKey

  @doc "The tuples to delete and the tuples to write, so that the store holds what the tables require."
  @spec between([TupleKey.t()], [TupleKey.t()]) :: {[TupleKey.t()], [TupleKey.t()]}
  def between(required, present) when is_list(required) and is_list(present) do
    wanted = by_triple(required)
    have = by_triple(present)

    deletes = for {triple, tuple} <- have, Map.get(wanted, triple) != tuple, do: tuple
    writes = for {triple, tuple} <- wanted, Map.get(have, triple) != tuple, do: tuple

    {sorted(deletes), sorted(writes)}
  end

  @doc """
  The difference as write calls, in the order a pass makes them. Each
  call carries at most `batch` changes, its deletes and its writes
  counted together, as the server counts them. No call carries a triple
  on both sides.
  """
  @spec writes([TupleKey.t()], [TupleKey.t()], pos_integer()) :: [Write.t()]
  def writes(deletes, writes, batch) when is_list(deletes) and is_list(writes) and batch > 0 do
    triples = MapSet.new(deletes, &TupleKey.triple/1)
    {rewritten, plain} = Enum.split_with(writes, &MapSet.member?(triples, TupleKey.triple(&1)))

    packed(deletes, plain, batch) ++ packed([], rewritten, batch)
  end

  @doc "The tuples in the order a difference and a drift report them: by triple."
  @spec sorted(Enumerable.t()) :: [TupleKey.t()]
  def sorted(tuples), do: Enum.sort_by(tuples, &TupleKey.triple/1)

  defp by_triple(tuples), do: Map.new(tuples, &{TupleKey.triple(&1), &1})

  defp packed([], [], _batch), do: []

  defp packed(deletes, writes, batch) do
    {call_deletes, rest_deletes} = Enum.split(deletes, batch)
    {call_writes, rest_writes} = Enum.split(writes, batch - length(call_deletes))

    [%Write{deletes: call_deletes, writes: call_writes} | packed(rest_deletes, rest_writes, batch)]
  end
end
