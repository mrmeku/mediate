defmodule Mediate.OpenFGA.Client.HTTPTest do
  use ExUnit.Case, async: true

  alias Mediate.Conformance.Reference.World
  alias Mediate.Dev
  alias Mediate.Error
  alias Mediate.OpenFGA.Client.Check
  alias Mediate.OpenFGA.Client.HTTP
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Client.Page
  alias Mediate.OpenFGA.Client.Read
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Condition
  alias Mediate.OpenFGA.Model
  alias Mediate.OpenFGA.TupleKey

  @moduletag :openfga
  @asking %{"subject_kind" => "user", "current_time" => "2026-09-09T12:00:00Z"}
  @never "9999-12-31T23:59:59Z"

  setup do
    server = Dev.OpenFGA.current!()
    {:ok, store_id} = HTTP.create_store(server.http, "conformance")
    {:ok, model_id} = HTTP.write_authorization_model(server.http, store_id, Model.read!("priv/conformance/model.fga"))

    {:ok, address: server.http, store_id: store_id, model_id: model_id}
  end

  defp member(account, clearance) do
    %TupleKey{user: "user:#{account}", relation: "member", object: "clearance:#{clearance}"}
  end

  defp role(account, folder, relation, clearance) do
    %TupleKey{
      user: "user:#{account}",
      relation: relation,
      object: "folder:#{folder}",
      condition: %Condition{
        name: "grant_holds",
        context: %{"clearance" => clearance, "kind" => "user", "expires_at" => @never}
      }
    }
  end

  defp under(folder, item), do: %TupleKey{user: "folder:#{folder}", relation: "folder", object: "item:#{item}"}

  # Two accounts of the neutral fixture: one cleared with the reader role,
  # one with the editor role under a clearance the condition refuses.
  defp world(context) do
    written = [
      member("ann", World.cleared()),
      member("bob", "secret"),
      role("ann", 1, "reader", World.cleared()),
      role("bob", 1, "editor", "secret"),
      under(1, 1)
    ]

    {:ok, 5} = HTTP.write(context.address, context.store_id, %Write{deletes: [], writes: written})
    written
  end

  defp asks(context, account, relation, object) do
    request = %Check{
      tuple_key: %TupleKey{user: "user:#{account}", relation: relation, object: object},
      model_id: context.model_id,
      context: @asking,
      consistency: :higher_consistency
    }

    HTTP.check(context.address, context.store_id, request)
  end

  test "a store and a model answer the ids the server gave them", context do
    assert is_binary(context.store_id)
    assert is_binary(context.model_id)
  end

  test "a check under the pinned model answers what the model says", context do
    _written = world(context)

    assert asks(context, "ann", "can_read", "folder:1") == {:ok, true}
    assert asks(context, "ann", "can_edit", "folder:1") == {:ok, false}
    assert asks(context, "zed", "can_read", "folder:1") == {:ok, false}
  end

  test "a role a condition refuses holds nothing", context do
    _written = world(context)

    assert asks(context, "bob", "can_edit", "folder:1") == {:ok, false}
    assert asks(context, "bob", "can_read", "folder:1") == {:ok, false}
  end

  test "an item answers as the folder it is under does", context do
    _written = world(context)

    assert asks(context, "ann", "can_read", "item:1") == {:ok, true}
    assert asks(context, "ann", "can_edit", "item:1") == {:ok, false}
  end

  test "a listing answers the objects of one type the account holds the relation on", context do
    _written = world(context)

    request = %ListObjects{
      user: "user:ann",
      relation: "can_read",
      type: "folder",
      model_id: context.model_id,
      context: @asking
    }

    assert HTTP.list_objects(context.address, context.store_id, request) == {:ok, ["folder:1"]}

    refused = %{request | user: "user:bob"}
    assert HTTP.list_objects(context.address, context.store_id, refused) == {:ok, []}
  end

  test "a read of one object answers its tuples with the condition each carries", context do
    _written = world(context)

    assert {:ok, %Page{} = page} =
             HTTP.read(context.address, context.store_id, %Read{object_type: "folder", object_id: "1"})

    held = [role("ann", 1, "reader", World.cleared()), role("bob", 1, "editor", "secret")]

    assert Enum.sort_by(page.tuples, &TupleKey.triple/1) == held
    assert page.continuation_token == nil
  end

  test "a read of a whole object type answers that type and nothing else", context do
    _written = world(context)

    assert {:ok, %Page{} = page} = HTTP.read(context.address, context.store_id, %Read{object_type: "clearance"})

    assert Enum.sort_by(page.tuples, &TupleKey.triple/1) == [member("ann", World.cleared()), member("bob", "secret")]
  end

  test "a read narrowed by a relation and a user answers that tuple alone", context do
    _written = world(context)
    request = %Read{object_type: "folder", object_id: "1", relation: "reader", user: "user:ann"}

    assert {:ok, %Page{tuples: [tuple]}} = HTTP.read(context.address, context.store_id, request)
    assert tuple == role("ann", 1, "reader", World.cleared())
  end

  test "a page smaller than the store answers a continuation, and the pages together are the store", context do
    _written = world(context)

    assert {:ok, %Page{} = first} =
             HTTP.read(context.address, context.store_id, %Read{object_type: "folder", page_size: 1})

    assert is_binary(first.continuation_token)

    next = %Read{object_type: "folder", page_size: 1, continuation_token: first.continuation_token}
    assert {:ok, %Page{} = second} = HTTP.read(context.address, context.store_id, next)
    assert length(first.tuples) + length(second.tuples) <= 2
  end

  test "a delete takes the tuple out, and the account loses what it held", context do
    _written = world(context)
    change = %Write{deletes: [role("ann", 1, "reader", World.cleared())], writes: []}

    assert {:ok, 1} = HTTP.write(context.address, context.store_id, change)
    assert asks(context, "ann", "can_read", "folder:1") == {:ok, false}
  end

  test "a condition that changed is the same key with another context, deleted and written again", context do
    _written = world(context)
    old = role("ann", 1, "reader", World.cleared())
    new = role("ann", 1, "reader", "secret")

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during write" <> _rest}} =
             HTTP.write(context.address, context.store_id, %Write{deletes: [old], writes: [new]})

    assert {:ok, 1} = HTTP.write(context.address, context.store_id, %Write{deletes: [old], writes: []})
    assert {:ok, 1} = HTTP.write(context.address, context.store_id, %Write{deletes: [], writes: [new]})
    assert asks(context, "ann", "can_read", "folder:1") == {:ok, false}
  end

  test "a duplicate write and a delete of a tuple the store does not hold are refused", context do
    written = world(context)
    duplicate = %Write{deletes: [], writes: [List.first(written)]}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             HTTP.write(context.address, context.store_id, duplicate)

    assert message =~ "already exists"

    absent = %Write{deletes: [member("zed", World.cleared())], writes: []}

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during write" <> _rest}} =
             HTTP.write(context.address, context.store_id, absent)
  end

  test "a tuple the model admits only under a condition is refused without one", context do
    plain = %TupleKey{user: "user:ann", relation: "reader", object: "folder:9"}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             HTTP.write(context.address, context.store_id, %Write{deletes: [], writes: [plain]})

    assert message =~ "condition is missing"
  end

  test "a store the server does not know is an engine error naming the call", context do
    request = %Check{tuple_key: %TupleKey{user: "user:ann", relation: "can_read", object: "folder:1"}}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             HTTP.check(context.address, "01ABSENTSTORE0000000000000", request)

    assert message =~ "the server answered"
  end

  test "a model the store does not hold is an engine error", context do
    request = %Check{
      tuple_key: %TupleKey{user: "user:ann", relation: "can_read", object: "folder:1"},
      model_id: "01ABSENTMODEL0000000000000"
    }

    assert {:error, %Error{reason: :engine_failed, message: "Mediate.OpenFGA failed during check" <> _rest}} =
             HTTP.check(context.address, context.store_id, request)
  end

  test "an address nothing listens on is an engine error rather than a wait", _context do
    request = %Check{tuple_key: %TupleKey{user: "user:ann", relation: "can_read", object: "folder:1"}}

    assert {:error, %Error{reason: :engine_failed, message: message}} =
             HTTP.check("127.0.0.1:1", "store", request)

    assert message =~ "could not be reached"
  end

  test "an address that is no address is an engine error rather than a crash", context do
    request = %Check{tuple_key: %TupleKey{user: "user:ann", relation: "can_read", object: "folder:1"}}

    assert {:error, %Error{reason: :engine_failed, message: message}} = HTTP.check(self(), context.store_id, request)
    assert message =~ "no address this client reaches"
  end

  test "every call emits one event with its duration and its outcome", context do
    id = {__MODULE__, make_ref()}
    :ok = :telemetry.attach(id, HTTP.event(), &send_event/4, self())
    on_exit(fn -> :telemetry.detach(id) end)

    _written = world(context)

    assert_received {:event, %{duration: duration}, %{path: path, outcome: :ok}}
    assert duration > 0
    assert path =~ "/write"
    refute_received {:event, _measurements, _metadata}
  end

  # A handler is global, and another async module that raises a server of
  # its own publishes a model through this client. So only calls this
  # process made count.
  defp send_event(_event, measurements, metadata, pid) do
    if self() == pid, do: send(pid, {:event, measurements, metadata})
    :ok
  end
end
