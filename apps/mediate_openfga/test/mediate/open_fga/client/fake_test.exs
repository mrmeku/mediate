defmodule Mediate.OpenFGA.Client.FakeTest do
  use ExUnit.Case, async: true

  alias Mediate.Error
  alias Mediate.OpenFGA.Client
  alias Mediate.OpenFGA.Client.Check
  alias Mediate.OpenFGA.Client.Fake
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Client.Page
  alias Mediate.OpenFGA.Client.Read
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Condition
  alias Mediate.OpenFGA.TupleKey

  setup do
    agent = start_supervised!(Fake)
    {:ok, store_id} = Fake.create_store(agent, "conformance")

    {:ok, agent: agent, store_id: store_id}
  end

  defp tuple(user, relation, object, condition \\ nil) do
    %TupleKey{user: user, relation: relation, object: object, condition: condition}
  end

  defp write!(context, deletes, writes) do
    Fake.write(context.agent, context.store_id, %Write{deletes: deletes, writes: writes})
  end

  test "a store is created under an id of its own and a model is published into it", context do
    assert {:ok, other} = Fake.create_store(context.agent, "another")
    assert other != context.store_id

    assert {:ok, "model-1"} =
             Fake.write_authorization_model(context.agent, context.store_id, %{"schema_version" => "1.1"})

    assert {:ok, "model-2"} =
             Fake.write_authorization_model(context.agent, context.store_id, %{"schema_version" => "1.1"})
  end

  test "a call against a store that is not there is an engine error naming the call", context do
    assert {:error,
            %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during write_authorization_model" <> _rest}} =
             Fake.write_authorization_model(context.agent, "store-404", %{})

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during read" <> _rest}} =
             Fake.read(context.agent, "store-404", %Read{object_type: "folder"})

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during write" <> _rest}} =
             Fake.write(context.agent, "store-404", %Write{deletes: [], writes: []})
  end

  test "a write puts its tuples in the store and answers how many changes it carried", context do
    reader = tuple("user:ann", "reader", "folder:1")
    member = tuple("user:ann", "member", "clearance:cleared")

    assert write!(context, [], [reader, member]) == {:ok, 2}
    assert Fake.tuples(context.agent, context.store_id) == [member, reader]
    assert write!(context, [member], []) == {:ok, 1}
    assert Fake.tuples(context.agent, context.store_id) == [reader]
  end

  test "a duplicate write is refused and the call changes nothing", context do
    reader = tuple("user:ann", "reader", "folder:1")
    assert write!(context, [], [reader]) == {:ok, 1}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             write!(context, [], [tuple("user:ann", "editor", "folder:1"), reader])

    assert message =~ "user:ann reader folder:1"
    assert Fake.tuples(context.agent, context.store_id) == [reader]
  end

  test "a delete of a tuple the store does not hold is refused and the call changes nothing", context do
    reader = tuple("user:ann", "reader", "folder:1")
    assert write!(context, [], [reader]) == {:ok, 1}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             write!(context, [reader, tuple("user:bob", "reader", "folder:1")], [])

    assert message =~ "user:bob reader folder:1"
    assert Fake.tuples(context.agent, context.store_id) == [reader]
  end

  test "a tuple key on both sides of one call is refused", context do
    cleared = tuple("user:ann", "reader", "folder:1", %Condition{name: "while_cleared"})
    assert write!(context, [], [tuple("user:ann", "reader", "folder:1")]) == {:ok, 1}

    assert {:error, %Error{reason: :engine_failed, message: message}} = write!(context, [cleared], [cleared])
    assert message =~ "deletes and writes user:ann reader folder:1"
  end

  test "a delete matches by the tuple key alone, so a condition on it is no part of the match", context do
    plain = tuple("user:ann", "reader", "folder:1")
    conditioned = tuple("user:ann", "reader", "folder:1", %Condition{name: "while_cleared", context: %{"a" => 1}})

    assert write!(context, [], [conditioned]) == {:ok, 1}
    assert write!(context, [plain], []) == {:ok, 1}
    assert Fake.tuples(context.agent, context.store_id) == []
  end

  test "a call carrying more changes than one call may is refused", context do
    writes = for id <- 1..(Client.max_tuples_per_write() + 1), do: tuple("user:ann", "reader", "folder:#{id}")

    assert {:error, %Error{reason: :engine_failed, message: message}} = write!(context, [], writes)
    assert message =~ "101 changes"
    assert Fake.tuples(context.agent, context.store_id) == []
  end

  test "writes fail once the fake has acknowledged the number it was given", context do
    :ok = Fake.fail_after(context.agent, 1)

    assert write!(context, [], [tuple("user:ann", "reader", "folder:1")]) == {:ok, 1}
    assert {:error, %Error{reason: :engine_failed, message: message}} = write!(context, [], [])
    assert message =~ "the fake was asked to fail this write"

    :ok = Fake.fail_after(context.agent, nil)
    assert write!(context, [], [tuple("user:bob", "reader", "folder:1")]) == {:ok, 1}
  end

  test "read pages by the limit it is given and filters by object, relation, and user", context do
    tuples = for id <- 1..3, do: tuple("user:ann", "reader", "folder:#{id}")
    assert write!(context, [], [tuple("user:bob", "editor", "folder:1") | tuples]) == {:ok, 4}

    assert {:ok, %Page{tuples: first, continuation_token: continuation}} =
             Fake.read(context.agent, context.store_id, %Read{object_type: "folder", page_size: 2})

    assert length(first) == 2
    assert continuation

    assert {:ok, %Page{tuples: rest, continuation_token: nil}} =
             Fake.read(context.agent, context.store_id, %Read{
               object_type: "folder",
               page_size: 2,
               continuation_token: continuation
             })

    assert length(rest) == 2

    assert {:ok, %Page{tuples: [held], continuation_token: nil}} =
             Fake.read(context.agent, context.store_id, %Read{
               object_type: "folder",
               object_id: "1",
               relation: "editor",
               user: "user:bob"
             })

    assert held.user == "user:bob"
    assert {:ok, %Page{tuples: []}} = Fake.read(context.agent, context.store_id, %Read{object_type: "clearance"})
  end

  test "check answers from the tuples the store holds directly", context do
    reader = tuple("user:ann", "reader", "folder:1")
    assert write!(context, [], [reader]) == {:ok, 1}

    assert Fake.check(context.agent, context.store_id, %Check{tuple_key: reader}) == {:ok, true}

    assert Fake.check(context.agent, context.store_id, %Check{tuple_key: tuple("user:bob", "reader", "folder:1")}) ==
             {:ok, false}
  end

  test "list_objects answers the objects of the type the user holds the relation on", context do
    tuples = [tuple("user:ann", "reader", "folder:2"), tuple("user:ann", "reader", "folder:1")]
    assert write!(context, [], [tuple("user:ann", "member", "clearance:cleared") | tuples]) == {:ok, 3}

    request = %ListObjects{user: "user:ann", relation: "reader", type: "folder"}
    assert Fake.list_objects(context.agent, context.store_id, request) == {:ok, ["folder:1", "folder:2"]}

    assert Fake.list_objects(context.agent, context.store_id, %{request | relation: "editor"}) == {:ok, []}
  end

  test "every call is recorded in the order it was made", context do
    assert write!(context, [], []) == {:ok, 0}
    assert {:ok, _page} = Fake.read(context.agent, context.store_id, %Read{object_type: "folder"})

    assert [{:create_store, "conformance"}, {:write, %Write{}}, {:read, %Read{}}] = Fake.calls(context.agent)
    assert [%Write{deletes: [], writes: []}] = Fake.writes(context.agent)
  end
end
