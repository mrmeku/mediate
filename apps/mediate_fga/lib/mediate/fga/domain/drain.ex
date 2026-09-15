defmodule Mediate.Fga.Domain.Drain do
  @moduledoc false
  # The arithmetic of a drain. Given the tuples an object requires and the
  # tuples the store holds for it, what the drain tells the store.
  #
  # Nothing here reads an event or a row. `difference/2` compares two lists
  # of tuples. That is why a drain that runs twice over the same object
  # writes nothing the second time. It is also why a marker that arrives
  # again costs a read and no write.
  #
  # The user, the relation, and the object are a tuple's key, and its
  # condition is a value on it. So a tuple whose condition changed is the
  # same key with another value: a delete and a write of that key. One call
  # refuses a key on both of its sides (OpenFGA 1.19.0). So the write of
  # such a key goes in a later call than its delete.

  alias Mediate.Fga.Client.Write
  alias Mediate.Fga.TupleKey

  @doc "The tuples to delete and the tuples to write, so that the store holds what the tables require."
  @spec difference([TupleKey.t()], [TupleKey.t()]) :: {[TupleKey.t()], [TupleKey.t()]}
  def difference(required, present) when is_list(required) and is_list(present) do
    wanted = by_key(required)
    have = by_key(present)

    deletes = for {key, tuple} <- have, Map.get(wanted, key) != tuple, do: tuple
    writes = for {key, tuple} <- wanted, Map.get(have, key) != tuple, do: tuple

    {sorted(deletes), sorted(writes)}
  end

  @doc """
  The difference as calls, in the order the drain makes them. Each call
  carries at most `batch` changes, its deletes and its writes counted
  together, as the server counts them. No call carries a key on both sides.
  """
  @spec calls([TupleKey.t()], [TupleKey.t()], pos_integer()) :: [Write.t()]
  def calls(deletes, writes, batch) when is_list(deletes) and is_list(writes) and batch > 0 do
    keys = MapSet.new(deletes, &TupleKey.key/1)
    {rewritten, plain} = Enum.split_with(writes, &MapSet.member?(keys, TupleKey.key(&1)))

    packed(deletes, plain, batch) ++ packed([], rewritten, batch)
  end

  @doc "The tuples in the order a difference and a drift report them: by key."
  @spec sorted(Enumerable.t()) :: [TupleKey.t()]
  def sorted(tuples), do: Enum.sort_by(tuples, &TupleKey.key/1)

  defp by_key(tuples), do: Map.new(tuples, &{TupleKey.key(&1), &1})

  defp packed([], [], _batch), do: []

  defp packed(deletes, writes, batch) do
    {call_deletes, rest_deletes} = Enum.split(deletes, batch)
    {call_writes, rest_writes} = Enum.split(writes, batch - length(call_deletes))

    [%Write{deletes: call_deletes, writes: call_writes} | packed(rest_deletes, rest_writes, batch)]
  end
end
