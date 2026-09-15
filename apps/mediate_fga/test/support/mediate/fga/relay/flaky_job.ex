defmodule Mediate.Fga.Relay.FlakyJob do
  @moduledoc """
  The test job with a delivery that reaches the far end and then fails,
  when the process that runs the pass says so. A pass runs in the process
  that called `Mediate.Fga.Relay.drain_once/1`. So a test says `refuse/1`
  before each pass and reads afterwards whether the rows the delivery wrote
  stayed.

  The failure comes after the write and not before it, on purpose. What it
  proves is that a pass that does not commit leaves nothing behind, not
  that a delivery which never ran wrote nothing.
  """

  @behaviour Mediate.Fga.Relay.Job

  use Boundary, top_level?: true, deps: [NimbleOptions, Mediate.Fga.Relay, Mediate.Fga.Relay.TestJob]

  alias Mediate.Fga.Relay.Entry
  alias Mediate.Fga.Relay.Job
  alias Mediate.Fga.Relay.TestJob

  @key __MODULE__

  @doc "Says whether the next delivery in this process fails after its write."
  @spec refuse(boolean()) :: :ok
  def refuse(refusing?) when is_boolean(refusing?) do
    _previous = Process.put(@key, refusing?)

    :ok
  end

  @impl Job
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: TestJob.options_schema()

  @impl Job
  @spec read(module(), keyword(), non_neg_integer(), pos_integer()) :: {:ok, [Entry.t()]}
  def read(repo, options, from, limit), do: TestJob.read(repo, options, from, limit)

  @impl Job
  @spec deliver(module(), keyword(), [Entry.t()]) :: :ok | {:error, :refused}
  def deliver(repo, options, entries) do
    :ok = TestJob.deliver(repo, options, entries)

    if Process.get(@key, false), do: {:error, :refused}, else: :ok
  end
end
