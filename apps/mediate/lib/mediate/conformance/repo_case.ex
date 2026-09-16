defmodule Mediate.Conformance.RepoCase do
  @moduledoc """
  The conformance case for a repo. `use Mediate.Conformance.RepoCase,
  repo: MyApp.Repo` writes the tests that hold the repo to the seam. The
  repo must answer `__mediate__/1`. It must export nothing outside the
  surface of the build it comes from. It must refuse, before any SQL,
  every query, write, and raw call on a protected schema that carries no
  decision and no exemption.

  The test starts the repo. The protected schema's table need not exist.

      defmodule MyApp.RepoTest do
        use Mediate.Conformance.RepoCase, repo: MyApp.Repo
      end

  An adopter that names a `Mediate.Conformance.RepoCase.Rows` module as
  well gets five more tests, one per guarantee in `guarantees/0`. Those
  five write to the database the rows module names.

      defmodule MyApp.RepoTest do
        use Mediate.Conformance.RepoCase, repo: MyApp.Repo, rows: MyApp.RepoRows
      end
  """

  import ExUnit.Assertions

  alias Mediate.Change
  alias Mediate.Conformance.RepoCase
  alias Mediate.Decision
  alias Mediate.Infrastructure.Surface
  alias Mediate.Schema
  alias Mediate.Test

  @joined {__MODULE__, :joined}

  @doc false
  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    async = Keyword.get(opts, :async, true)
    rows = Keyword.get(opts, :rows)

    quote bind_quoted: [repo: repo, async: async, rows: rows] do
      use ExUnit.Case, async: async

      @mediate_repo repo
      @mediate_rows rows

      test "the repo answers __mediate__/1 and exports only what the surface it was compiled against classifies" do
        RepoCase.assert_surface(@mediate_repo)
      end

      for {name, arity} <- RepoCase.swept(repo) do
        @mediate_call {name, arity}

        test "Repo.#{name}/#{arity} on a protected schema without a decision or an exemption is refused before SQL" do
          RepoCase.assert_refused(@mediate_repo, @mediate_call)
        end
      end

      if rows do
        setup tags do
          RepoCase.setup_rows(@mediate_rows, tags)
        end

        for {id, sentence} <- RepoCase.guarantees() do
          @mediate_guarantee id

          test "#{id} #{sentence}" do
            RepoCase.assert_guarantee(@mediate_guarantee, @mediate_repo, @mediate_rows)
          end
        end
      end
    end
  end

  @guarantees [
    {"E1", "A single-row write to an audited schema emits one change event with every fact field that changed"},
    {"E2", "A bulk write to an audited schema raises and emits nothing"},
    {"E3", "A write that goes around the seam emits nothing"},
    {"E4", "A consumer that writes to the same repository from its handler joins the write transaction"},
    {"E5",
     "A mediated read of a protected schema emits one access event with its rows and its decision, and a read " <>
       "under an exemption emits none"}
  ]

  @doc """
  The guarantee table of `docs/conformance.md` under "The guarantees" as data, one id and one
  sentence per row. The freeze test in `mediate` holds it to the document
  row for row.
  """
  @spec guarantees() :: [{String.t(), String.t()}]
  def guarantees, do: @guarantees

  @doc "Runs the assertion of one guarantee, by its id, against the repo and the rows module."
  @spec assert_guarantee(String.t(), module(), module()) :: :ok
  def assert_guarantee("E1", repo, rows), do: assert_one_change(repo, rows)
  def assert_guarantee("E2", repo, rows), do: assert_bulk_refused(repo, rows)
  def assert_guarantee("E3", repo, rows), do: assert_around_silent(repo, rows)
  def assert_guarantee("E4", repo, rows), do: assert_handler_joins(repo, rows)
  def assert_guarantee("E5", repo, rows), do: assert_read_evented(repo, rows)

  @doc "Fails unless the repo answers `__mediate__/1` and exports only classified functions."
  @spec assert_surface(module()) :: :ok
  def assert_surface(repo) when is_atom(repo) do
    if !(Code.ensure_loaded?(repo) and function_exported?(repo, :__mediate__, 1)) do
      flunk("#{inspect(repo)} does not use Mediate.Repo")
    end

    classified = MapSet.new(Surface.all(), fn {name, arity, _bucket} -> {name, arity} end)

    case Enum.reject(repo.__info__(:functions), &MapSet.member?(classified, &1)) do
      [] -> :ok
      [{name, arity} | _rest] -> flunk(unclassified(repo, name, arity))
    end
  end

  @doc "The query, write, and raw functions the repo exports, each swept with fixture arguments."
  @spec swept(module()) :: [{atom(), non_neg_integer()}]
  def swept(repo) when is_atom(repo) do
    exported = MapSet.new(repo.__info__(:functions))

    for {name, arity, bucket} <- Surface.all(), bucket != :plumbing, MapSet.member?(exported, {name, arity}) do
      {name, arity}
    end
  end

  @doc "Calls the function with fixture arguments on the protected schema and expects the refusal."
  @spec assert_refused(module(), {atom(), non_neg_integer()}) :: :ok
  def assert_refused(repo, {name, arity}) when is_atom(repo) do
    args = RepoCase.Fixture.args(name, arity)

    assert_raise(Mediate.Error, fn ->
      case apply(repo, name, args) do
        %Stream{} = stream -> Enum.to_list(stream)
        stream when is_function(stream) -> Enum.to_list(stream)
        other -> other
      end
    end)

    :ok
  end

  @doc "The rows module's own setup, where it defines one."
  @spec setup_rows(module(), map()) :: :ok
  def setup_rows(rows, tags) when is_atom(rows) and is_map(tags) do
    if Code.ensure_loaded?(rows) and function_exported?(rows, :setup, 1), do: rows.setup(tags), else: :ok
  end

  @doc "E1: one event for the insert, one for the update, with the fact fields the update changed."
  @spec assert_one_change(module(), module()) :: :ok
  def assert_one_change(repo, rows) when is_atom(repo) and is_atom(rows) do
    {row, created} = Test.changes(fn -> repo.insert!(rows.row(), mediate: rows.mediation()) end)
    assert [%{operation: :create}] = created

    changeset = rows.change(row)
    {_updated, changed} = Test.changes(fn -> repo.update!(changeset, mediate: rows.mediation()) end)
    assert [event] = changed
    assert_updated(event, rows, row, changeset)
  end

  @doc "E2: every bulk call the repo exports raises on an audited schema, and none of them publishes."
  @spec assert_bulk_refused(module(), module()) :: :ok
  def assert_bulk_refused(repo, rows) when is_atom(repo) and is_atom(rows) do
    row = repo.insert!(rows.row(), mediate: rows.mediation())
    sets = Enum.to_list(rows.change(row).changes)

    {_refusals, changes} =
      Test.changes(fn -> Enum.each(bulk(row.__struct__, sets), &assert_bulk(repo, rows, &1)) end)

    assert changes == []
    :ok
  end

  @doc "E3: a write the seam never saw publishes nothing, and the write reaches the row."
  @spec assert_around_silent(module(), module()) :: :ok
  def assert_around_silent(repo, rows) when is_atom(repo) and is_atom(rows) do
    row = repo.insert!(rows.row(), mediate: rows.mediation())
    {:ok, changes} = Test.changes(fn -> rows.around(row) end)
    read = repo.get!(row.__struct__, id(row), mediate: rows.mediation())

    assert changes == []
    refute facts(read) == facts(row), "#{inspect(rows)}.around/1 left the row as it was"
    :ok
  end

  @doc "E4: the handler's own write is in the transaction the write opened, so a rollback takes it too."
  @spec assert_handler_joins(module(), module()) :: :ok
  def assert_handler_joins(repo, rows) when is_atom(repo) and is_atom(rows) do
    schema = rows.row().__struct__
    counted = repo.aggregate(schema, :count, mediate: rows.mediation())
    handler = {__MODULE__, make_ref()}
    config = %{repo: repo, rows: rows, pid: self()}
    :ok = :telemetry.attach(handler, Change.event(), &__MODULE__.__join__/4, config)

    try do
      assert repo.transaction(fn -> discarded(repo, rows) end) == {:error, :discarded}
      assert Process.get(@joined) == true, "the handler's write ran outside the write's transaction"
    after
      :telemetry.detach(handler)
      Process.delete(@joined)
    end

    assert repo.aggregate(schema, :count, mediate: rows.mediation()) == counted
    :ok
  end

  @doc """
  E5: a `get` under a decision is one access event that names the row, the
  decision, and the subject. An `exists?` is one that names no row. A read
  under an exemption is none.
  """
  @spec assert_read_evented(module(), module()) :: :ok
  def assert_read_evented(repo, rows) when is_atom(repo) and is_atom(rows) do
    row = repo.insert!(rows.protected(), mediate: rows.mediation())
    schema = row.__struct__
    decision = rows.decision(row)
    assert %Decision{verdict: :allow} = decision

    {read, [got]} = Test.accesses(fn -> repo.get(schema, id(row), mediate: decision) end)
    assert read == row
    assert_access(got, {:get, 3}, :read, [id(row)], :rows, schema, repo, decision)

    {true, [exists]} = Test.accesses(fn -> repo.exists?(schema, mediate: decision) end)
    assert_access(exists, {:exists?, 2}, :read, [], :value, schema, repo, decision)

    {_read, none} = Test.accesses(fn -> repo.get(schema, id(row), mediate: rows.mediation()) end)
    assert none == []
    :ok
  end

  @doc false
  @spec __join__([atom()], map(), map(), map()) :: :ok
  def __join__(_event, _measurements, _payload, %{repo: repo, rows: rows, pid: pid}) do
    if self() == pid and is_nil(Process.get(@joined)) do
      Process.put(@joined, repo.in_transaction?())
      _row = repo.insert!(rows.row(), mediate: rows.mediation())
    end

    :ok
  end

  # A write and a rollback of the transaction it ran in: what the handler
  # wrote goes with it, because it was the same transaction.
  defp discarded(repo, rows) do
    _row = repo.insert!(rows.row(), mediate: rows.mediation())
    repo.rollback(:discarded)
  end

  defp assert_bulk(repo, rows, {name, args}) do
    if function_exported?(repo, name, length(args)) do
      error = assert_raise(Mediate.Error, fn -> apply(repo, name, mediated(args, rows.mediation())) end)
      assert Exception.message(error) =~ "bulk write to an audited schema"
    end
  end

  defp bulk(schema, sets) do
    [
      {:update_all, [schema, [set: sets], []]},
      {:delete_all, [schema, []]},
      {:insert_all, [schema, [Map.new(sets)], []]}
    ]
  end

  defp mediated(args, mediation), do: List.replace_at(args, -1, mediate: mediation)

  # The one event the update made, against the row the update started from.
  defp assert_updated(event, rows, row, changeset) do
    assert event.operation == :update
    assert event.schema == row.__struct__
    assert event.changes == expected(rows, row, changeset)
    assert event.target == {type(row.__struct__), id(row)}
    :ok
  end

  # What the event has to carry: every fact field the change sets, from the
  # value the row held to the value the change gives it.
  defp expected(rows, row, %Ecto.Changeset{changes: changes}) do
    schema = row.__struct__
    columns = Enum.filter(Schema.fact_columns(schema), &Map.has_key?(changes, &1))

    if columns == [] do
      flunk("#{inspect(rows)}.change/1 sets no fact field of #{inspect(schema)}")
    end

    Map.new(columns, &{&1, {Map.get(row, &1), Map.fetch!(changes, &1)}})
  end

  defp assert_access(event, call, activity, ids, shape, schema, repo, decision) do
    assert event.call == call
    assert event.activity == activity
    assert event.ids == ids
    assert event.count == length(ids)
    assert event.shape == shape
    assert event.schema == schema
    assert event.repo == repo
    assert event.object_type == Schema.object_type_of(schema)
    assert event.decision_id == decision.id
    assert event.subject == decision.subject
    assert event.operation_id == decision.operation_id
    assert %DateTime{} = event.time
    :ok
  end

  defp facts(row), do: Map.take(row, Schema.fact_columns(row.__struct__))

  defp type(schema), do: Schema.object_type_of(schema) || Schema.kind_of(schema)

  defp id(row), do: Schema.id_of(row)

  defp unclassified(repo, name, arity) do
    "#{inspect(repo)} exports #{name}/#{arity}, which the surface this build was written against " <>
      "does not classify; " <>
      "a repo function outside the surface runs unchecked"
  end
end
