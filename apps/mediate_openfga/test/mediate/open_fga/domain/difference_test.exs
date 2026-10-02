defmodule Mediate.OpenFGA.Domain.DifferenceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Condition
  alias Mediate.OpenFGA.Domain.Difference
  alias Mediate.OpenFGA.TupleKey

  property "the writes of a difference leave the store holding what the object requires" do
    check all({required, present} <- states(), batch <- integer(1..8)) do
      {deletes, writes} = Difference.between(required, present)

      assert applied(Difference.writes(deletes, writes, batch), present) == Enum.sort(Enum.uniq(required))
    end
  end

  property "a store that already holds what an object requires is told nothing" do
    check all({required, _present} <- states(), batch <- integer(1..8)) do
      {deletes, writes} = Difference.between(required, required)

      assert {deletes, writes} == {[], []}
      assert Difference.writes(deletes, writes, batch) == []
    end
  end

  property "no write carries a triple on both of its sides, and the delete of a triple comes before its write" do
    check all({required, present} <- states(), batch <- integer(1..8)) do
      {deletes, writes} = Difference.between(required, present)
      calls = Difference.writes(deletes, writes, batch)

      for %Write{} = call <- calls do
        assert MapSet.disjoint?(triples(call.deletes), triples(call.writes))
      end

      for triple <- MapSet.intersection(triples(deletes), triples(writes)) do
        assert at(calls, triple, & &1.deletes) < at(calls, triple, & &1.writes)
      end
    end
  end

  property "every write carries at most the changes one call may carry" do
    check all({required, present} <- states(), batch <- integer(1..8)) do
      {deletes, writes} = Difference.between(required, present)

      for %Write{} = call <- Difference.writes(deletes, writes, batch) do
        assert (length(call.deletes) + length(call.writes)) in 1..batch
      end
    end
  end

  property "a tuple whose condition changed is one triple deleted and written again" do
    check all(tuple <- tuple_key(), clearance <- member_of(~w(low high))) do
      was = %{tuple | condition: %Condition{name: "while", context: %{"clearance" => clearance}}}
      now = %{was | condition: %Condition{name: "while", context: %{"clearance" => clearance <> " enough"}}}
      {deletes, writes} = Difference.between([now], [was])

      assert {deletes, writes} == {[was], [now]}

      assert Difference.writes(deletes, writes, 8) == [
               %Write{deletes: [was], writes: []},
               %Write{deletes: [], writes: [now]}
             ]
    end
  end

  test "sorted puts tuples in the order of their triples" do
    later = %TupleKey{user: "user:bo", relation: "reader", object: "folder:1"}
    earlier = %TupleKey{user: "user:ann", relation: "reader", object: "folder:1"}

    assert Difference.sorted([later, earlier]) == [earlier, later]
  end

  # The store as the writes leave it: a delete takes a triple away and a
  # write puts one back, whatever the triple held before.
  defp applied(calls, present) do
    held = Map.new(present, &{TupleKey.triple(&1), &1})

    calls
    |> Enum.reduce(held, fn %Write{} = call, store ->
      store = Map.drop(store, Enum.map(call.deletes, &TupleKey.triple/1))

      Enum.reduce(call.writes, store, &Map.put(&2, TupleKey.triple(&1), &1))
    end)
    |> Map.values()
    |> Enum.sort()
  end

  defp triples(tuples), do: MapSet.new(tuples, &TupleKey.triple/1)

  defp at(calls, triple, side) do
    Enum.find_index(calls, fn call -> Enum.any?(side.(call), &(TupleKey.triple(&1) == triple)) end)
  end

  # A pair of states over the same small space of triples. So a required
  # tuple and a present one meet often enough for a difference to have both
  # sides.
  defp states do
    gen all(required <- tuples(), present <- tuples()) do
      {Enum.uniq_by(required, &TupleKey.triple/1), Enum.uniq_by(present, &TupleKey.triple/1)}
    end
  end

  defp tuples, do: list_of(tuple_key(), max_length: 12)

  defp tuple_key do
    gen all(
          user <- member_of(~w(user:ann user:bo user:cy)),
          relation <- member_of(~w(reader writer owner)),
          object <- member_of(~w(folder:1 folder:2 item:1)),
          condition <- one_of([constant(nil), map(context(), &%Condition{name: "while", context: &1})])
        ) do
      %TupleKey{user: user, relation: relation, object: object, condition: condition}
    end
  end

  defp context, do: map(member_of(~w(low high)), &%{"clearance" => &1})
end
