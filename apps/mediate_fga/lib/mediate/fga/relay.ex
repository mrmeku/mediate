defmodule Mediate.Fga.Relay do
  @moduledoc """
  Batched, ordered delivery from a Postgres table. One runner per job, a
  cursor that says how far that runner has got, and a wake-up. The wake-up
  is for the process that wrote a row and does not want to wait for the
  next tick.

  The shape is the same wherever a producer makes records faster than a
  consumer ships them. Rows go into a table in the same transaction as the
  work that produced them. Something else reads them afterwards, in order,
  and hands them to whatever is slow. What is slow is a
  `Mediate.Fga.Relay.Job`, which says how to read a batch above a position
  and what a delivery of one means. Nothing here knows what a row holds.

  A pass runs in one transaction. It:

  - takes an advisory lock on the runner's name, so a second node steps
    aside and delivers no row twice
  - reads a batch above the cursor
  - delivers it
  - advances the cursor
  - commits

  A delivery that fails rolls the pass back. The cursor stays where it was,
  and the next pass reads the batch again. That is at-least-once delivery
  in position order. A job's `c:Mediate.Fga.Relay.Job.deliver/3` must
  accept a batch it has seen before.

  Every pass emits `[:mediate, :relay, :pass]`, whether it delivered,
  stepped aside, or failed. The measurements are `delivered` and, where
  there was one, `position`. The metadata is the runner's `name`, its
  `job`, and either the `%Mediate.Fga.Relay.Pass{}` under `pass` or the
  term the job reported under `error`.

  An application puts one of these in its supervision tree:

  ```elixir
  {Mediate.Fga.Relay,
   runners: [
     [name: :markers, repo: MyApp.Repo, job: MyApp.Markers, batch: 500]
   ]}
  ```

  It calls `wake/1` after a write that produced rows. A test drives
  `drain_once/1` and starts nothing. `options_schema/0` is the option list
  a runner takes.

  The repo a runner gets is one whose calls carry no decision: a plain Ecto
  repo, or a repo the seam knows as the owner's. The cursor states nothing
  about a subject or an object, so there is no decision to carry. The rows
  a job reads are the application's to place where its own rules allow.

  The cursor and the advisory lock are Postgres. That is why `postgrex` is
  a dependency of this package's `lib`.
  """

  use Boundary,
    top_level?: true,
    deps: [Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [Cursor, Entry, Job, Options, Pass]

  use Supervisor

  alias Mediate.Fga.Relay.Infrastructure.Drain
  alias Mediate.Fga.Relay.Infrastructure.Runner
  alias Mediate.Fga.Relay.Options
  alias Mediate.Fga.Relay.Pass

  @supervisor_schema NimbleOptions.new!(
                       runners: [
                         type: {:list, :keyword_list},
                         required: true,
                         doc: "One option list per runner, each as `options_schema/0` gives."
                       ],
                       name: [type: :atom, doc: "The name to register the supervisor itself under."]
                     )

  @doc "The options one runner takes. Fields: #{NimbleOptions.docs(Options.schema())}"
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: Options.schema()

  @doc "Starts a supervisor over the runners named. Options: #{NimbleOptions.docs(@supervisor_schema)}"
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) when is_list(options) do
    options = NimbleOptions.validate!(options, @supervisor_schema)
    {name, options} = Keyword.pop(options, :name)
    Supervisor.start_link(__MODULE__, options, if(name, do: [name: name], else: []))
  end

  @doc """
  Drains the runner's rows once, now, and answers what the pass did. This
  is what a runner's tick calls, and what a test calls instead of a start
  of one. Options: `options_schema/0`.
  """
  @spec drain_once(keyword()) :: {:ok, Pass.t()} | {:error, term()}
  def drain_once(options) when is_list(options), do: Drain.once(Options.validate!(options))

  @doc """
  Asks a runner to pass now and not at its next tick, from the process
  that wrote the rows. It answers `:ok` before the pass, so a delivery
  holds no writer's transaction open. The runner drops a wake-up that
  arrives while a pass is already due, because that pass reads everything
  committed before it runs. The runner is a pid, or the name a registered
  one started under.
  """
  @spec wake(GenServer.server()) :: :ok
  def wake(runner), do: Runner.wake(runner)

  @impl Supervisor
  def init(options) do
    children = Enum.map(options[:runners], &{Runner, &1})
    Supervisor.init(children, strategy: :one_for_one)
  end
end
