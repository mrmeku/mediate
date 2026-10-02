defmodule Mediate.Conformance.RepoCase do
  @moduledoc """
  The repo case. `use Mediate.Conformance.RepoCase, repo: MyApp.Repo`
  writes the tests that hold the repo to the mediated repo's contract. The
  repo must answer `__mediate__/1`. It must export nothing outside the
  surface of the build it comes from. It must refuse, before any SQL,
  every query, write, and raw call on a protected schema that carries no
  decision and no exemption.

  The test starts the repo. The protected schema's table need not exist.

      defmodule MyApp.RepoTest do
        use Mediate.Conformance.RepoCase, repo: MyApp.Repo
      end

  An adopter that names a `Mediate.Conformance.Specimen` module as well
  gets five more tests, one per repo requirement of
  `Mediate.Conformance.Requirement`. Those five write to the database the
  specimen names.

      defmodule MyApp.RepoTest do
        use Mediate.Conformance.RepoCase, repo: MyApp.Repo, specimen: MyApp.RepoSpecimen
      end

  Options:

  - `repo:` the repo to hold, required.
  - `specimen:` a `Mediate.Conformance.Specimen` module. The five repo
    requirements exist only when given.
  - `async:` default `true`.
  """

  import ExUnit.Assertions

  alias Mediate.Conformance.RepoCase
  alias Mediate.Conformance.Requirement
  alias Mediate.Decision
  alias Mediate.IdentityWrite
  alias Mediate.Infrastructure.Surface
  alias Mediate.Schema
  alias Mediate.Test

  @joined {__MODULE__, :joined}

  @doc false
  defmacro __using__(opts) do
    repo = Keyword.fetch!(opts, :repo)
    async = Keyword.get(opts, :async, true)
    specimen = Keyword.get(opts, :specimen)

    quote bind_quoted: [repo: repo, async: async, specimen: specimen] do
      use ExUnit.Case, async: async

      @mediate_repo repo
      @mediate_specimen specimen

      test "the repo answers __mediate__/1 and exports only what the surface it was compiled against classifies" do
        RepoCase.assert_mediated(@mediate_repo)
      end

      for {name, arity} <- RepoCase.exports(repo) do
        @mediate_call {name, arity}

        test "Repo.#{name}/#{arity} on a protected schema without a decision or an exemption is refused before SQL" do
          RepoCase.assert_refused(@mediate_repo, @mediate_call)
        end
      end

      if specimen do
        setup tags do
          RepoCase.setup_specimen(@mediate_specimen, tags)
        end

        for %Requirement{id: id} <- Requirement.all(:repo) do
          @mediate_requirement id

          test Requirement.test_name(id) do
            RepoCase.run(@mediate_requirement, @mediate_repo, @mediate_specimen)
          end
        end
      end
    end
  end

  @doc "Run the procedure of one repo requirement, by its id, against the repo and the specimen."
  @spec run(String.t(), module(), module()) :: :ok
  def run("repo-01", repo, specimen), do: assert_one_identity_write(repo, specimen)
  def run("repo-02", repo, specimen), do: assert_bulk_refused(repo, specimen)
  def run("repo-03", repo, specimen), do: assert_around_silent(repo, specimen)
  def run("repo-04", repo, specimen), do: assert_handler_joins(repo, specimen)
  def run("repo-05", repo, specimen), do: assert_read_evented(repo, specimen)

  @doc "Fails unless the repo answers `__mediate__/1` and exports only classified functions."
  @spec assert_mediated(module()) :: :ok
  def assert_mediated(repo) when is_atom(repo) do
    if !(Code.ensure_loaded?(repo) and function_exported?(repo, :__mediate__, 1)) do
      flunk("#{inspect(repo)} does not use Mediate.Repo")
    end

    classified = MapSet.new(Surface.all(), fn {name, arity, _bucket} -> {name, arity} end)

    case Enum.reject(repo.__info__(:functions), &MapSet.member?(classified, &1)) do
      [] -> :ok
      [{name, arity} | _rest] -> flunk(unclassified(repo, name, arity))
    end
  end

  @doc "The query, write, and raw functions the repo exports, each swept with the case's own arguments."
  @spec exports(module()) :: [{atom(), non_neg_integer()}]
  def exports(repo) when is_atom(repo) do
    exported = MapSet.new(repo.__info__(:functions))

    for {name, arity, bucket} <- Surface.all(), bucket != :plumbing, MapSet.member?(exported, {name, arity}) do
      {name, arity}
    end
  end

  @doc "Calls the function with the case's arguments on the tableless schema and expects the refusal."
  @spec assert_refused(module(), {atom(), non_neg_integer()}) :: :ok
  def assert_refused(repo, {name, arity}) when is_atom(repo) do
    args = RepoCase.Arguments.args(name, arity)

    assert_raise(Mediate.Error, fn ->
      case apply(repo, name, args) do
        %Stream{} = stream -> Enum.to_list(stream)
        stream when is_function(stream) -> Enum.to_list(stream)
        other -> other
      end
    end)

    :ok
  end

  @doc "The specimen's own setup, where it defines one."
  @spec setup_specimen(module(), map()) :: :ok
  def setup_specimen(specimen, tags) when is_atom(specimen) and is_map(tags) do
    if Code.ensure_loaded?(specimen) and function_exported?(specimen, :setup, 1), do: specimen.setup(tags), else: :ok
  end

  @doc "`repo-01`: one event for the insert, one for the update, with the fact fields the update changed."
  @spec assert_one_identity_write(module(), module()) :: :ok
  def assert_one_identity_write(repo, specimen) when is_atom(repo) and is_atom(specimen) do
    by = specimen.authorized_by()
    {row, created} = Test.writes(fn -> repo.insert!(specimen.identity_row(), authorized_by: by) end)
    assert [%{operation: :create}] = created

    changeset = specimen.fact_changeset(row)
    {_updated, changed} = Test.writes(fn -> repo.update!(changeset, authorized_by: by) end)
    assert [event] = changed
    assert_updated(event, specimen, row, changeset)
  end

  @doc "`repo-02`: every bulk call the repo exports raises on an identity schema, and none of them publishes."
  @spec assert_bulk_refused(module(), module()) :: :ok
  def assert_bulk_refused(repo, specimen) when is_atom(repo) and is_atom(specimen) do
    row = repo.insert!(specimen.identity_row(), authorized_by: specimen.authorized_by())
    sets = Enum.to_list(specimen.fact_changeset(row).changes)

    {_refusals, writes} =
      Test.writes(fn -> Enum.each(bulk(row.__struct__, sets), &assert_bulk(repo, specimen, &1)) end)

    assert writes == []
    :ok
  end

  @doc "`repo-03`: a write the mediated repo never saw publishes nothing, and the write reaches the row."
  @spec assert_around_silent(module(), module()) :: :ok
  def assert_around_silent(repo, specimen) when is_atom(repo) and is_atom(specimen) do
    row = repo.insert!(specimen.identity_row(), authorized_by: specimen.authorized_by())
    {:ok, writes} = Test.writes(fn -> specimen.write_around(row) end)
    read = repo.get!(row.__struct__, id(row), authorized_by: specimen.authorized_by())

    assert writes == []
    refute facts(read) == facts(row), "#{inspect(specimen)}.write_around/1 left the row as it was"
    :ok
  end

  @doc "`repo-04`: the handler's own write is in the transaction the write opened, so a rollback takes it too."
  @spec assert_handler_joins(module(), module()) :: :ok
  def assert_handler_joins(repo, specimen) when is_atom(repo) and is_atom(specimen) do
    schema = specimen.identity_row().__struct__
    counted = repo.aggregate(schema, :count, authorized_by: specimen.authorized_by())
    handler = {__MODULE__, make_ref()}
    config = %{repo: repo, specimen: specimen, pid: self()}
    :ok = :telemetry.attach(handler, IdentityWrite.event(), &__MODULE__.__join__/4, config)

    try do
      assert repo.transaction(fn -> discarded(repo, specimen) end) == {:error, :discarded}
      assert Process.get(@joined) == true, "the handler's write ran outside the write's transaction"
    after
      :telemetry.detach(handler)
      Process.delete(@joined)
    end

    assert repo.aggregate(schema, :count, authorized_by: specimen.authorized_by()) == counted
    :ok
  end

  @doc """
  `repo-05`: a `get` under a decision is one resource read event that
  names the row, the decision, and the subject. An `exists?` is one that
  names no row. A read under an exemption is none.
  """
  @spec assert_read_evented(module(), module()) :: :ok
  def assert_read_evented(repo, specimen) when is_atom(repo) and is_atom(specimen) do
    row = repo.insert!(specimen.protected_row(), authorized_by: specimen.authorized_by())
    schema = row.__struct__
    decision = specimen.read_decision(row)
    assert %Decision{effect: :allow} = decision

    {read, [got]} = Test.reads(fn -> repo.get(schema, id(row), authorized_by: decision) end)
    assert read == row
    assert_read(got, {:get, 3}, :one, [id(row)], :rows, schema, repo, decision)

    {true, [exists]} = Test.reads(fn -> repo.exists?(schema, authorized_by: decision) end)
    assert_read(exists, {:exists?, 2}, :one, [], :scalar, schema, repo, decision)

    {_read, none} = Test.reads(fn -> repo.get(schema, id(row), authorized_by: specimen.authorized_by()) end)
    assert none == []
    :ok
  end

  @doc false
  @spec __join__([atom()], map(), map(), map()) :: :ok
  def __join__(_event, _measurements, _payload, %{repo: repo, specimen: specimen, pid: pid}) do
    if self() == pid and is_nil(Process.get(@joined)) do
      Process.put(@joined, repo.in_transaction?())
      _row = repo.insert!(specimen.identity_row(), authorized_by: specimen.authorized_by())
    end

    :ok
  end

  # A write and a rollback of the transaction it ran in: what the handler
  # wrote goes with it, because it was the same transaction.
  defp discarded(repo, specimen) do
    _row = repo.insert!(specimen.identity_row(), authorized_by: specimen.authorized_by())
    repo.rollback(:discarded)
  end

  defp assert_bulk(repo, specimen, {name, args}) do
    if function_exported?(repo, name, length(args)) do
      error = assert_raise(Mediate.Error, fn -> apply(repo, name, authorized(args, specimen.authorized_by())) end)
      assert Exception.message(error) =~ "bulk write to an identity schema"
    end
  end

  defp bulk(schema, sets) do
    [
      {:update_all, [schema, [set: sets], []]},
      {:delete_all, [schema, []]},
      {:insert_all, [schema, [Map.new(sets)], []]}
    ]
  end

  defp authorized(args, by), do: List.replace_at(args, -1, authorized_by: by)

  # The one event the update made, against the row the update started from.
  defp assert_updated(event, specimen, row, changeset) do
    assert event.operation == :update
    assert event.schema == row.__struct__
    assert event.changes == expected(specimen, row, changeset)
    assert event.resource == {type(row.__struct__), id(row)}
    :ok
  end

  # What the event has to carry: every fact field the change sets, from the
  # value the row held to the value the change gives it.
  defp expected(specimen, row, %Ecto.Changeset{changes: changes}) do
    schema = row.__struct__
    columns = Enum.filter(Schema.fact_columns(schema), &Map.has_key?(changes, &1))

    if columns == [] do
      flunk("#{inspect(specimen)}.fact_changeset/1 sets no fact field of #{inspect(schema)}")
    end

    Map.new(columns, &{&1, {Map.get(row, &1), Map.fetch!(changes, &1)}})
  end

  defp assert_read(event, repo_function, cardinality, primary_keys, result_shape, schema, repo, decision) do
    assert event.repo_function == repo_function
    assert event.cardinality == cardinality
    assert event.primary_keys == primary_keys
    assert event.count == length(primary_keys)
    assert event.result_shape == result_shape
    assert event.schema == schema
    assert event.repo == repo
    assert event.resource_type == Schema.resource_type_of(schema)
    assert event.decision_id == decision.id
    assert event.subject == decision.subject
    assert event.correlation_id == decision.correlation_id
    assert %DateTime{} = event.read_at
    :ok
  end

  defp facts(row), do: Map.take(row, Schema.fact_columns(row.__struct__))

  defp type(schema), do: Schema.resource_type_of(schema) || Schema.identity_of(schema)

  defp id(row), do: Schema.id_of(row)

  defp unclassified(repo, name, arity) do
    "#{inspect(repo)} exports #{name}/#{arity}, which the surface this build was written against " <>
      "does not classify; " <>
      "a repo function outside the surface runs unchecked"
  end
end
