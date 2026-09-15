defmodule OutsideCaller do
  @moduledoc false
  # A caller outside `Mediate.*`, for the library exemption's refusal. The
  # tuple keeps the Sandboxed call off the tail position, so the frame stays.

  @spec read(module(), term()) :: {:read, term()}
  def read(repo, option), do: {:read, repo.all(Mediate.Fixture.Folder, mediate: option)}
end

defmodule Mediate.Infrastructure.SeamTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2, subquery: 1]

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Mediate.Change
  alias Mediate.Decision
  alias Mediate.Dev.Sandbox
  alias Mediate.Error
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.Id
  alias Mediate.Test.AroundAdapter
  alias Mediate.Test.Fake
  alias Mediate.TestRepos.Owner
  alias Mediate.TestRepos.Sandboxed

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    :ok = Mediate.Test.with_config(adapter: Fake)
    folder = Sandboxed.insert!(%Folder{name: "root"}, mediate: {:exempt, "seed"})
    item = Sandboxed.insert!(%Item{title: "first", folder_id: folder.id}, mediate: {:exempt, "seed"})
    %{folder: folder, item: item, decision: decision(:folder, folder.id)}
  end

  describe "the query bucket" do
    test "all under a decision for the root's type runs, and for another type is refused", %{decision: decision} do
      assert [%Folder{}] = Sandboxed.all(Folder, mediate: decision)

      error = assert_raise(Error, fn -> Sandboxed.all(Item, mediate: decision) end)
      assert %Error{reason: :unmediated} = error

      assert Exception.message(error) =~
               "Repo.all/2 on #{inspect(Item)} carries a decision for :folder, which does not cover it"
    end

    test "a query without the option is refused naming the function and the caller" do
      error =
        assert_raise(Error, fn ->
          returned = Sandboxed.one(Folder)
          flunk("returned " <> inspect(returned))
        end)

      assert %Error{reason: :unmediated} = error

      assert Exception.message(error) ==
               "Repo.one/2 on Mediate.Fixture.Folder carries no decision and no exemption (from Mediate.Infrastructure.SeamTest)"
    end

    test "an unprotected schema passes without a decision" do
      assert [] = Sandboxed.all(Membership)
      assert Sandboxed.aggregate(Account, :count) == 0
    end

    test "preload of a carried association is allowed and of an uncarried protected schema is refused",
         %{folder: folder, item: item, decision: decision} do
      assert %Folder{items: [%Item{}]} = Sandboxed.preload(folder, :items, mediate: decision)
      assert %Folder{memberships: []} = Sandboxed.preload(folder, :memberships, mediate: decision)

      assert_raise Error, ~r/on Mediate.Fixture.Folder/, fn ->
        Sandboxed.preload(item, :folder, mediate: decision(:item, item.id))
      end
    end

    test "preload without a decision is refused", %{folder: folder} do
      assert_raise Error, ~r/Repo.preload\/3/, fn -> Sandboxed.preload(folder, :items) end
    end

    test "a join with a carried source is allowed and with an uncarried protected source is refused",
         %{decision: decision, item: item} do
      carried = from(f in Folder, join: i in assoc(f, :items), select: i.title)
      assert ["first"] = Sandboxed.all(carried, mediate: decision)

      uncarried = from(i in Item, join: f in assoc(i, :folder), select: f.name)

      assert_raise Error, ~r/on Mediate.Fixture.Folder/, fn ->
        Sandboxed.all(uncarried, mediate: decision(:item, item.id))
      end

      by_source = from(i in Item, join: f in Folder, on: f.id == i.folder_id, select: f.name)
      assert_raise Error, ~r/does not cover it/, fn -> Sandboxed.all(by_source, mediate: decision(:item, item.id)) end
    end

    test "aggregate, exists?, get, get_by, all_by, reload, and stream carry the decision",
         %{folder: folder, decision: decision} do
      assert Sandboxed.aggregate(Folder, :count, mediate: decision) == 1
      assert Sandboxed.aggregate(Folder, :max, :id, mediate: decision) == folder.id
      assert Sandboxed.exists?(Folder, mediate: decision)
      assert %Folder{} = Sandboxed.get(Folder, folder.id, mediate: decision)
      assert %Folder{} = Sandboxed.get_by(Folder, [name: "root"], mediate: decision)
      assert [%Folder{}] = Sandboxed.all_by(Folder, [name: "root"], mediate: decision)
      assert %Folder{} = Sandboxed.reload(folder, mediate: decision)

      assert [%Folder{}] =
               fn -> Enum.to_list(Sandboxed.stream(Folder, mediate: decision)) end
               |> Sandboxed.transaction()
               |> elem(1)

      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.aggregate(Folder, :count) end
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.exists?(Folder) end
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.reload(folder) end
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.transaction(fn -> Sandboxed.stream(Folder) end) end
    end

    test "a subquery root is judged by its inner source", %{decision: decision} do
      query = from(s in subquery(from(f in Folder, select: %{id: f.id})), select: s.id)
      assert [_id] = Sandboxed.all(query, mediate: decision)
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.all(query) end
    end

    test "a denied decision raises before the query", %{folder: folder} do
      denied = %{decision(:folder, folder.id) | verdict: :deny}
      assert_raise Error, ~r/may not/, fn -> Sandboxed.all(Folder, mediate: denied) end
    end

    test "an unknown option shape is refused as invalid" do
      assert_raise NimbleOptions.ValidationError, fn -> Sandboxed.all(Folder, mediate: :please) end
      assert_raise NimbleOptions.ValidationError, fn -> Sandboxed.all(Folder, mediate: {:exempt, ""}) end
    end
  end

  describe "exemptions" do
    test "a declared exemption admits the call and a library exemption from outside the library is refused" do
      assert [%Folder{}] = Sandboxed.all(Folder, mediate: {:exempt, "report"})

      assert {:read, [%Folder{}]} = OutsideCaller.read(Sandboxed, {:exempt, "report"})
      error = assert_raise(Error, fn -> OutsideCaller.read(Sandboxed, {:exempt, :library}) end)
      assert Exception.message(error) =~ "accepted only from a Mediate.* caller"
      assert Exception.message(error) =~ "(from #{inspect(OutsideCaller)})"
    end

    test "the owner-role repo needs no option", %{folder: folder} do
      # The owner repo connects to the committed database, where the sandboxed rows are not visible.
      query = from(f in Folder, where: f.id == ^folder.id)
      assert [] = Owner.all(query)
      assert %{rows: [[1]]} = Owner.query!("SELECT 1")
    end
  end

  describe "the raw bucket" do
    test "query/3 without an exemption is refused, with a decision is invalid, with an exemption runs", %{
      decision: decision
    } do
      assert_raise Error, ~r/Repo.query\/3/, fn -> Sandboxed.query("SELECT 1", [], []) end
      assert_raise Error, ~r/Repo.query\/3/, fn -> Sandboxed.query("SELECT 1") end

      assert_raise Error, ~r/takes an exemption, not a decision/, fn ->
        Sandboxed.query("SELECT 1", [], mediate: decision)
      end

      assert {:ok, %{rows: [[1]]}} = Sandboxed.query("SELECT 1", [], mediate: {:exempt, "probe"})
      assert %{rows: [[1]]} = Sandboxed.query!("SELECT 1", [], mediate: {:exempt, "probe"})
    end
  end

  describe "the write bucket" do
    test "a write on a protected schema needs a decision for its type", %{folder: folder, decision: decision} do
      assert {:ok, %Folder{name: "renamed"}} =
               folder
               |> Changeset.change(name: "renamed")
               |> Sandboxed.update(mediate: decision)

      assert_raise Error, ~r/Repo.insert\/2 on Mediate.Fixture.Folder/, fn ->
        Sandboxed.insert(%Folder{name: "other"})
      end

      assert_raise Error, ~r/decision for :folder/, fn ->
        Sandboxed.insert!(%Item{title: "x"}, mediate: decision)
      end

      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.delete(folder) end
    end

    test "a nested write of a carried schema is allowed and of an uncarried protected schema is refused",
         %{folder: folder, item: item, decision: decision} do
      loaded = Sandboxed.preload(folder, :items, mediate: decision)

      changeset =
        loaded
        |> Changeset.change()
        |> Changeset.put_assoc(:items, [%Item{title: "second"} | loaded.items])

      assert {:ok, %Folder{items: items}} = Sandboxed.update(changeset, mediate: decision)
      assert length(items) == 2

      nested =
        %{item | folder: nil}
        |> Changeset.change()
        |> Changeset.put_assoc(:folder, %Folder{name: "new parent"})

      assert_raise Error, ~r/on Mediate.Fixture.Folder/, fn ->
        Sandboxed.update(nested, mediate: decision(:item, item.id))
      end
    end

    test "insert_all with entries and with a query source carries a decision for the root's type",
         %{folder: folder, item: item, decision: decision} do
      items = decision(:item, item.id)
      assert {1, nil} = Sandboxed.insert_all(Item, [%{title: "bulk", folder_id: folder.id}], mediate: items)
      source = from(i in Item, select: %{title: i.title, folder_id: i.folder_id})
      assert {2, nil} = Sandboxed.insert_all(Item, source, mediate: items)
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.insert_all(Item, [%{title: "bulk"}]) end

      assert_raise Error, ~r/carries a decision for :folder/, fn ->
        Sandboxed.insert_all(Item, [%{title: "bulk"}], mediate: decision)
      end
    end

    test "update_all and delete_all on a protected schema carry the decision", %{item: item, decision: decision} do
      assert {1, nil} = Sandboxed.update_all(Folder, [set: [name: "all"]], mediate: decision)
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.update_all(Folder, set: [name: "none"]) end
      assert {1, nil} = Sandboxed.delete_all(Item, mediate: decision(:item, item.id))

      assert_raise Error, ~r/carries a decision for :folder/, fn ->
        Sandboxed.delete_all(Item, mediate: decision)
      end

      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.delete_all(Folder) end
    end

    test "an Ecto.Multi run through transaction carries each operation's own option",
         %{folder: folder, item: item, decision: decision} do
      multi =
        Multi.new()
        |> Multi.insert(:item, %Item{title: "in multi", folder_id: folder.id}, mediate: decision(:item, item.id))
        |> Multi.update_all(:rename, Folder, [set: [name: "multi"]], mediate: decision)

      assert {:ok, %{item: %Item{}, rename: {1, nil}}} = Sandboxed.transaction(multi)

      unmediated = Multi.insert(Multi.new(), :item, %Item{title: "no option"})
      assert_raise Error, ~r/carries no decision/, fn -> Sandboxed.transaction(unmediated) end
    end

    test "an upsert on a fact schema is refused naming the schema", %{folder: folder} do
      membership = %Membership{account_id: "acct-1", role: :reader, folder_id: folder.id}
      error = assert_raise(Error, fn -> Sandboxed.insert(membership, on_conflict: :nothing) end)
      assert %Error{reason: :invalid} = error
      assert Exception.message(error) =~ "invalid upsert: "
      assert Exception.message(error) =~ "on Mediate.Fixture.Membership"
      assert Exception.message(error) =~ "write the rows one at a time"
    end

    test "a bulk write to an audited schema is refused, exemption or not", %{folder: folder} do
      error = assert_raise(Error, fn -> Sandboxed.update_all(Membership, set: [role: :editor]) end)
      assert %Error{reason: :invalid} = error
      assert Exception.message(error) =~ "is a bulk write to an audited schema"

      assert_raise Error, ~r/audited schema/, fn -> Sandboxed.delete_all(Membership) end

      assert_raise Error, ~r/audited schema/, fn ->
        Sandboxed.insert_all(Membership, [%{account_id: "a", role: :reader, folder_id: folder.id}])
      end

      assert_raise Error, ~r/audited schema/, fn ->
        Sandboxed.update_all(Account, set: [clearance: "none"], mediate: {:exempt, "unchanged"})
      end
    end

    test "a bulk write to a schema that declares no kind runs", %{folder: folder} do
      assert {1, nil} = Sandboxed.update_all(Item, [set: [title: "renamed"]], mediate: {:exempt, "rename"})
      assert {1, nil} = Sandboxed.delete_all(Item, mediate: {:exempt, "clear"})

      assert {1, nil} =
               Sandboxed.insert_all(Item, [%{title: "third", folder_id: folder.id}], mediate: {:exempt, "seed"})
    end
  end

  describe "change events" do
    test "a single-row write publishes one change carrying every fact field that changed",
         %{folder: folder, decision: decision} do
      subject = {:user, "user-9"}
      decision = %{decision | subject: subject}

      {membership, [created]} =
        Mediate.Test.changes(fn ->
          Sandboxed.insert!(%Membership{account_id: "acct-5", role: :reader, folder_id: folder.id},
            mediate: {:exempt, "grant"}
          )
        end)

      assert created.operation == :create
      assert created.kind == :role
      assert created.target == {:role, membership.id}

      assert created.changes == %{
               account_id: {nil, "acct-5"},
               folder_id: {nil, folder.id},
               role: {nil, :reader},
               subject_kind: {nil, :user}
             }

      assert created.actor == Change.library()
      assert created.actor_kind == :non_person_entity
      assert created.schema == Membership
      assert %DateTime{} = created.time

      {_updated, [changed]} =
        Mediate.Test.changes(fn ->
          membership
          |> Changeset.change(role: :editor)
          |> Sandboxed.update!(mediate: decision)
        end)

      assert changed.operation == :update
      assert changed.changes == %{role: {:reader, :editor}}
      assert changed.actor == subject
      assert changed.actor_kind == :user
      assert changed.operation_id == decision.operation_id
      assert changed.decision_id == decision.id
      assert created.decision_id == nil

      {_deleted, [removed]} =
        Mediate.Test.changes(fn -> Sandboxed.delete!(membership, mediate: {:exempt, "revoke"}) end)

      assert removed.operation == :delete

      assert removed.changes == %{
               account_id: {"acct-5", nil},
               folder_id: {folder.id, nil},
               role: {:reader, nil},
               subject_kind: {:user, nil}
             }
    end

    test "a write that changes no fact field publishes a change with no changes" do
      account = Sandboxed.insert!(%Account{id: "acct-6", clearance: "secret"})

      {_same, [published]} =
        Mediate.Test.changes(fn ->
          account
          |> Changeset.change(clearance: "secret")
          |> Sandboxed.update!()
        end)

      assert published.changes == %{}
      assert published.target == {:user, "acct-6"}
    end

    test "a schema that declares no kind publishes nothing, and so does the owner-role repo", %{folder: folder} do
      {_item, []} =
        Mediate.Test.changes(fn ->
          Sandboxed.insert!(%Item{title: "second", folder_id: folder.id}, mediate: {:exempt, "seed"})
        end)

      {_account, []} = Mediate.Test.changes(fn -> Owner.insert!(%Account{id: "acct-7", clearance: "secret"}) end)
    end

    test "a write that fails publishes nothing" do
      changeset =
        %Account{id: "acct-8"}
        |> Changeset.change(clearance: "x")
        |> Changeset.add_error(:clearance, "no")

      assert {{:error, %Changeset{}}, []} = Mediate.Test.changes(fn -> Sandboxed.insert(changeset) end)
    end
  end

  describe "access events" do
    test "a read under a decision publishes one access naming the rows, the decision, and the subject",
         %{folder: folder, decision: decision} do
      {[read], [event]} = Mediate.Test.accesses(fn -> Sandboxed.all(Folder, mediate: decision) end)

      assert read.id == folder.id
      assert event.object_type == :folder
      assert event.schema == Folder
      assert event.repo == Sandboxed
      assert event.call == {:all, 2}
      assert event.activity == :query
      assert event.ids == [folder.id]
      assert event.count == 1
      assert event.shape == :rows
      assert event.subject == decision.subject
      assert event.subject_kind == :user
      assert event.decision_id == decision.id
      assert event.operation_id == decision.operation_id
      assert %DateTime{} = event.time
    end

    test "each shape of read is one access: a row, a value, a stream, and a preload", %{
      folder: folder,
      decision: decision
    } do
      {_row, [got]} = Mediate.Test.accesses(fn -> Sandboxed.get(Folder, folder.id, mediate: decision) end)
      assert %{call: {:get, 3}, activity: :read, ids: [_id], shape: :rows} = got

      {nil, [missed]} = Mediate.Test.accesses(fn -> Sandboxed.get(Folder, -1, mediate: decision) end)
      assert %{activity: :read, ids: [], count: 0, shape: :rows} = missed

      {true, [exists]} = Mediate.Test.accesses(fn -> Sandboxed.exists?(Folder, mediate: decision) end)
      assert %{call: {:exists?, 2}, activity: :read, ids: [], shape: :value} = exists

      {1, [counted]} = Mediate.Test.accesses(fn -> Sandboxed.aggregate(Folder, :count, mediate: decision) end)
      assert %{call: {:aggregate, 3}, activity: :query, ids: [], shape: :value} = counted

      {{:ok, [_row]}, [streamed]} =
        Mediate.Test.accesses(fn ->
          Sandboxed.transaction(fn -> Enum.to_list(Sandboxed.stream(Folder, mediate: decision)) end)
        end)

      assert %{call: {:stream, 2}, activity: :query, ids: [], shape: :stream} = streamed

      {%Folder{}, [preloaded]} =
        Mediate.Test.accesses(fn -> Sandboxed.preload(folder, :items, mediate: decision) end)

      assert %{call: {:preload, 3}, activity: :read, ids: [_id], shape: :rows} = preloaded
    end

    test "an exempt read, a read the owner-role repo makes, and a read of an unprotected schema publish nothing" do
      {[_row], []} = Mediate.Test.accesses(fn -> Sandboxed.all(Folder, mediate: {:exempt, "seed"}) end)
      {rows, []} = Mediate.Test.accesses(fn -> Owner.all(Folder) end)
      assert is_list(rows)
      {[], []} = Mediate.Test.accesses(fn -> Sandboxed.all(Membership) end)
    end
  end

  describe "the seam's edges" do
    test "insert_or_update inserts a new struct and updates a loaded one", %{folder: folder, decision: decision} do
      assert {:ok, %Folder{id: id}} =
               Sandboxed.insert_or_update(Changeset.change(%Folder{name: "fresh"}), mediate: decision(:folder, nil))

      assert {:ok, %Folder{id: ^id, name: "kept"}} =
               %Folder{id: id, name: "fresh"}
               |> Ecto.put_meta(state: :loaded)
               |> Changeset.change(name: "kept")
               |> Sandboxed.insert_or_update(mediate: decision(:folder, id))

      assert {:ok, %Folder{name: "again"}} =
               folder
               |> Changeset.change(name: "again")
               |> Sandboxed.insert_or_update(mediate: decision)
    end

    test "delete_all and update_all on a table name pass, as the name declares no object type" do
      assert {0, nil} = Sandboxed.delete_all("mediate_fixture_accounts")
      assert {0, nil} = Sandboxed.update_all("mediate_fixture_accounts", set: [clearance: "none"])
    end

    test "prepare_query reached outside an override judges the query with an empty mediation" do
      query = Ecto.Queryable.to_query(Folder)

      error =
        assert_raise(Error, fn ->
          prepared = Sandboxed.prepare_query(:all, query, [])
          flunk("prepared " <> inspect(prepared))
        end)

      assert Exception.message(error) ==
               "Repo.all/2 on #{inspect(Folder)} carries no decision and no exemption (from #{inspect(__MODULE__)})"

      error = assert_raise(Error, fn -> Sandboxed.prepare_query(:update_all, query, []) end)
      assert Exception.message(error) =~ "Repo.update_all/3"

      unprotected = Ecto.Queryable.to_query(Account)
      assert {^unprotected, []} = Sandboxed.prepare_query(:all, unprotected, [])
    end
  end

  describe "around_query" do
    test "the adapter's around_query receives the query or changeset and the decision", %{
      folder: folder,
      decision: decision
    } do
      Mediate.Test.with_config(adapter: AroundAdapter)
      assert [%Folder{}] = Sandboxed.all(Folder, mediate: decision)
      assert_received {:around_query, %Ecto.Query{}, ^decision}

      assert {:ok, _folder} =
               folder
               |> Changeset.change(name: "wrapped")
               |> Sandboxed.update(mediate: decision)

      assert_received {:around_query, %Changeset{}, ^decision}

      assert [%Folder{}] = Sandboxed.all(Folder, mediate: {:exempt, "no wrap"})
      refute_received {:around_query, _query, _decision}
    end
  end

  defp decision(type, id) do
    %Decision{
      id: Id.new(),
      subject: {:user, "user-1"},
      object: {type, id},
      operation: :read,
      verdict: :allow,
      reason: :allowed,
      adapter: Fake,
      policy_version: nil,
      operation_id: Id.new(),
      at: DateTime.utc_now()
    }
  end
end
