defmodule Mediate.Fga.OutboxCase do
  @moduledoc """
  The case template that proves a binding's drain. `use
  Mediate.Fga.OutboxCase, repo: MyApp.Repo, population: MyApp.Population`
  defines a test module that holds the marker outbox, the mapping behind
  it, and the store together. What the tables say is what the store holds,
  and it stays that way.

  This runs against a server and the application's own tables, under the
  configuration entry and the binding the current process has. The repo is
  the bound one, since the handler writes markers through it and a runner
  reads them from it.

  The template holds five things:

  - A write through the seam leaves a marker.
  - A settle makes the store agree with the tables. A second settle costs
    nothing, because a drain writes differences and not changes.
  - A pass that reached the server and then lost its answer converges when
    it runs again.
  - Rows taken away take their tuples with them.
  - A change no marker saw is drift a reconcile reports. A mark of every
    object and a settle take it away.

  Options:

  - `repo:` the mediated repo of the binding, required.
  - `population:` the `Mediate.Fga.Population` module, required.
  - `sandbox:` a module that answers `setup(repo, tags)`, which the template
    calls first in every test, for a repo that needs a checkout before the
    test runs. Omit it for a repo that needs none.
  - `async:` default `false`. The change handler is on for the whole run
    and not for the current process alone, and every test writes the same
    store besides.
  """

  import ExUnit.Assertions

  alias Mediate.Fga
  alias Mediate.Fga.Client.Write
  alias Mediate.Fga.Drift
  alias Mediate.Fga.Infrastructure.Store
  alias Mediate.Fga.Outbox
  alias Mediate.Fga.Relay.Cursor
  alias Mediate.Fga.TupleKey

  @limit 1_000

  @doc false
  defmacro __using__(opts) do
    {opts, _binding} = Code.eval_quoted(opts, [], __CALLER__)

    config = %{
      repo: Keyword.fetch!(opts, :repo),
      population: Keyword.fetch!(opts, :population),
      sandbox: Keyword.get(opts, :sandbox)
    }

    [preamble(config, Keyword.get(opts, :async, false)), marking(), draining(), drifting()]
  end

  @doc false
  @spec __setup__(map(), map()) :: {:ok, keyword()}
  def __setup__(config, tags) do
    if config.sandbox, do: :ok = config.sandbox.setup(config.repo, tags)
    :ok = Outbox.attach()
    ExUnit.Callbacks.on_exit(&Outbox.detach/0)
    :ok = config.population.clear(config.repo)
    :ok = Fga.settle()
    {:ok, store} = Store.resolve(Fga)
    :ok = emptied(store)
    :ok = config.population.write(config.repo)

    {:ok, outbox_case: config, store: store}
  end

  @doc false
  @spec markers_are_written(map()) :: true
  def markers_are_written(config) do
    {:ok, entries} = Outbox.read(config.repo, [], Cursor.position(config.repo, Outbox.runner()), @limit)

    assert(entries != [], "writing the population through the seam left no marker")
    assert(Enum.all?(entries, &is_binary(&1.payload)))
  end

  @doc false
  @spec settling_agrees(map()) :: true
  def settling_agrees(_config) do
    assert(Fga.settle() == :ok)
    assert({:ok, %Drift{} = drift} = Fga.reconcile())
    assert(Drift.clean?(drift), inspect(drift))
    assert(held() != [], "the population states no tuple, so there is nothing to hold the drain to")
  end

  @doc false
  @spec settling_again_costs_nothing(map()) :: true
  def settling_again_costs_nothing(config) do
    :ok = Fga.settle()
    position = Cursor.position(config.repo, Outbox.runner())
    tuples = held()

    assert(Fga.settle() == :ok)
    assert(Cursor.position(config.repo, Outbox.runner()) == position)
    assert(held() == tuples)
  end

  @doc false
  @spec a_lost_answer_converges(map(), Store.t()) :: true
  def a_lost_answer_converges(config, store) do
    assert(Store.converge(store, Store.objects(store)) == :ok)
    assert(Fga.settle() == :ok)
    assert({:ok, %Drift{} = drift} = Fga.reconcile())
    assert(Drift.clean?(drift), inspect(drift))
    assert(Cursor.position(config.repo, Outbox.runner()) > 0)
  end

  @doc false
  @spec rows_taken_away_take_their_tuples(map()) :: true
  def rows_taken_away_take_their_tuples(config) do
    :ok = Fga.settle()
    assert(held() != [], "the population states no tuple, so there is nothing to hold the drain to")

    :ok = config.population.clear(config.repo)

    assert(Fga.settle() == :ok)
    assert(held() == [])
  end

  @doc false
  @spec an_unmarked_change_is_drift(map()) :: true
  def an_unmarked_change_is_drift(config) do
    :ok = Fga.settle()
    :ok = Outbox.detach()
    :ok = config.population.disturb(config.repo)
    :ok = Outbox.attach()

    assert({:ok, %Drift{} = drift} = Fga.reconcile())
    refute(Drift.clean?(drift), "the disturbance left the store agreeing with the tables")
    assert(Fga.mark_all() == :ok)
    assert(Fga.settle() == :ok)
    assert({:ok, %Drift{} = clean} = Fga.reconcile())
    assert(Drift.clean?(clean), inspect(clean))
  end

  # Every tuple the store holds of the types the mapping names. After a
  # settle that is what the tables require, and after a clear it is nothing.
  defp held do
    {:ok, store} = Store.resolve(Fga)
    {:ok, tuples} = Store.present(store)

    Enum.sort_by(tuples, &TupleKey.key/1)
  end

  # A store that holds nothing of the mapping's types. So a test starts
  # from what the empty tables say and not from what an earlier one left.
  defp emptied(store) do
    {:ok, tuples} = Store.present(store)

    tuples
    |> Enum.chunk_every(store.batch)
    |> Enum.each(fn chunk ->
      {:ok, _count} = store.client.write(store.endpoint, store.store, %Write{deletes: chunk, writes: []})
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
      test "a write through the seam leaves a marker for the objects it affected" do
        unquote(__MODULE__).markers_are_written(@outbox_case)
      end
    end
  end

  defp draining do
    quote do
      test "settling makes the store hold what the tables require" do
        unquote(__MODULE__).settling_agrees(@outbox_case)
      end

      test "settling a second time moves no cursor and writes no tuple" do
        unquote(__MODULE__).settling_again_costs_nothing(@outbox_case)
      end

      test "a pass whose writes reached the store and whose answer was lost converges when it runs again",
           %{store: store} do
        unquote(__MODULE__).a_lost_answer_converges(@outbox_case, store)
      end

      test "rows taken away take their tuples with them" do
        unquote(__MODULE__).rows_taken_away_take_their_tuples(@outbox_case)
      end
    end
  end

  defp drifting do
    quote do
      test "a change no marker saw is drift, which marking everything and settling takes away" do
        unquote(__MODULE__).an_unmarked_change_is_drift(@outbox_case)
      end
    end
  end
end
