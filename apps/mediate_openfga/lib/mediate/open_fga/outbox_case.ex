defmodule Mediate.OpenFGA.OutboxCase do
  @moduledoc """
  The case template that holds a deployment's outbox to what a sync
  relies on. `use Mediate.OpenFGA.OutboxCase, repo: MyApp.Repo,
  population: MyApp.Population` defines a test module that holds the
  outbox, the mapping behind it, and the store together. What the tables
  say is what the store holds, and it stays that way.

  This runs against a server and the deployment's own tables, under the
  configuration entry and the binding the current process has. The repo
  is the bound one, since the handler writes markers through it and a
  runner reads them from it.

  The template holds five things:

  - A write marks its objects.
  - A sync makes the store agree with the tables. A second sync costs
    nothing, because a pass writes differences and not changes.
  - A pass that reached the server and then lost its answer is written on
    the next pass.
  - Rows taken away take their tuples with them.
  - A write no marker saw is drift a reconcile reports. A mark of every
    object and a sync take it away.

  Options:

  - `repo:` the mediated repo of the binding, required.
  - `population:` the `Mediate.OpenFGA.Population` module, required.
  - `setup:` a module that answers `setup(repo, tags)`, which the
    template calls first in every test, for a repo that needs a checkout
    before the test runs. Omit it for a repo that needs none.
  - `async:` default `false`. The handler is on for the whole run and not
    for the current process alone, and every test writes the same store
    besides.
  """

  import ExUnit.Assertions

  alias Mediate.OpenFGA
  alias Mediate.OpenFGA.Client.Write
  alias Mediate.OpenFGA.Drift
  alias Mediate.OpenFGA.Infrastructure.Store
  alias Mediate.OpenFGA.Outbox
  alias Mediate.OpenFGA.TupleKey
  alias Mediate.Relay.Cursor

  @limit 1_000

  @doc false
  defmacro __using__(opts) do
    {opts, _binding} = Code.eval_quoted(opts, [], __CALLER__)

    config = %{
      repo: Keyword.fetch!(opts, :repo),
      population: Keyword.fetch!(opts, :population),
      setup: Keyword.get(opts, :setup)
    }

    [preamble(config, Keyword.get(opts, :async, false)), marking(), syncing(), drifting()]
  end

  @doc false
  @spec __setup__(map(), map()) :: {:ok, keyword()}
  def __setup__(config, tags) do
    if config.setup, do: :ok = config.setup.setup(config.repo, tags)
    :ok = Outbox.attach()
    ExUnit.Callbacks.on_exit(&Outbox.detach/0)
    :ok = config.population.clear(config.repo)
    :ok = OpenFGA.sync()
    {:ok, store} = Store.resolve(OpenFGA)
    :ok = emptied(store)
    :ok = config.population.write(config.repo)

    {:ok, outbox_case: config, store: store}
  end

  @doc false
  @spec markers_are_written(map()) :: true
  def markers_are_written(config) do
    {:ok, entries} = Outbox.read(config.repo, [], Cursor.position(config.repo, Outbox.runner()), @limit)

    assert(entries != [], "writing the population through the mediated repo left no marker")
    assert(Enum.all?(entries, &is_binary(&1.payload)))
  end

  @doc false
  @spec sync_agrees(map()) :: true
  def sync_agrees(_config) do
    assert(OpenFGA.sync() == :ok)
    assert({:ok, %Drift{} = drift} = OpenFGA.reconcile())
    assert(Drift.empty?(drift), inspect(drift))
    assert(held() != [], "the population states no tuple, so there is nothing to hold the outbox to")
  end

  @doc false
  @spec second_sync_costs_nothing(map()) :: true
  def second_sync_costs_nothing(config) do
    :ok = OpenFGA.sync()
    position = Cursor.position(config.repo, Outbox.runner())
    tuples = held()

    assert(OpenFGA.sync() == :ok)
    assert(Cursor.position(config.repo, Outbox.runner()) == position)
    assert(held() == tuples)
  end

  @doc false
  @spec a_lost_answer_is_written_again(map(), Store.t()) :: true
  def a_lost_answer_is_written_again(config, store) do
    assert(Store.sync(store, Store.objects(store)) == :ok)
    assert(OpenFGA.sync() == :ok)
    assert({:ok, %Drift{} = drift} = OpenFGA.reconcile())
    assert(Drift.empty?(drift), inspect(drift))
    assert(Cursor.position(config.repo, Outbox.runner()) > 0)
  end

  @doc false
  @spec rows_taken_away_take_their_tuples(map()) :: true
  def rows_taken_away_take_their_tuples(config) do
    :ok = OpenFGA.sync()
    assert(held() != [], "the population states no tuple, so there is nothing to hold the outbox to")

    :ok = config.population.clear(config.repo)

    assert(OpenFGA.sync() == :ok)
    assert(held() == [])
  end

  @doc false
  @spec an_unmarked_write_is_drift(map()) :: true
  def an_unmarked_write_is_drift(config) do
    :ok = OpenFGA.sync()
    :ok = Outbox.detach()
    :ok = config.population.change(config.repo)
    :ok = Outbox.attach()

    assert({:ok, %Drift{} = drift} = OpenFGA.reconcile())
    refute(Drift.empty?(drift), "the change left the store agreeing with the tables")
    assert(OpenFGA.mark_all() == :ok)
    assert(OpenFGA.sync() == :ok)
    assert({:ok, %Drift{} = empty} = OpenFGA.reconcile())
    assert(Drift.empty?(empty), inspect(empty))
  end

  # Every tuple the store holds of the types the mapping names. After a
  # sync that is what the tables require, and after a clear it is nothing.
  defp held do
    {:ok, store} = Store.resolve(OpenFGA)
    {:ok, tuples} = Store.present(store)

    Enum.sort_by(tuples, &TupleKey.triple/1)
  end

  # A store that holds nothing of the mapping's types. So a test starts
  # from what the empty tables say and not from what an earlier one left.
  defp emptied(store) do
    {:ok, tuples} = Store.present(store)

    tuples
    |> Enum.chunk_every(store.batch)
    |> Enum.each(fn chunk ->
      {:ok, _count} = store.client.write(store.address, store.store_id, %Write{deletes: chunk, writes: []})
    end)
  end

  defp preamble(config, async) do
    quote do
      use ExUnit.Case, async: unquote(async)

      @outbox_case unquote(Macro.escape(config))

      setup tags do
        unquote(__MODULE__).__setup__(@outbox_case, tags)
      end
    end
  end

  defp marking do
    quote do
      test "a write marks its objects" do
        unquote(__MODULE__).markers_are_written(@outbox_case)
      end
    end
  end

  defp syncing do
    quote do
      test "a sync makes the store agree with the tables" do
        unquote(__MODULE__).sync_agrees(@outbox_case)
      end

      test "a second sync moves no cursor and writes no tuple" do
        unquote(__MODULE__).second_sync_costs_nothing(@outbox_case)
      end

      test "a lost answer is written on the next pass", %{store: store} do
        unquote(__MODULE__).a_lost_answer_is_written_again(@outbox_case, store)
      end

      test "rows taken away take their tuples" do
        unquote(__MODULE__).rows_taken_away_take_their_tuples(@outbox_case)
      end
    end
  end

  defp drifting do
    quote do
      test "an unmarked write is drift, which marking everything and syncing takes away" do
        unquote(__MODULE__).an_unmarked_write_is_drift(@outbox_case)
      end
    end
  end
end
