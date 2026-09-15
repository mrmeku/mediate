defmodule ExampleFga.Application do
  @moduledoc """
  The boot of the example on the graph.

  The boot does these things, in order:

  - The configuration names the server and the store.
  - The binding names the repo the drain reads the markers and the tables
    through, the model file, the mapping, and the guard.
  - The boot attaches the handler that writes a marker for every change.
  - The supervisor starts the consumer of the events, the repos, and the
    runner that delivers the markers.
  - Once the tree is up, the boot publishes the model as a policy version.

  The runner drains the outbox into the store on its interval. It starts
  here and not in a test. A test settles the store itself, and a runner
  beside it reads the same markers from a connection of its own. So the
  test configuration leaves the repos to the ephemeral cluster and the
  runner to the tests, and with them the publish. A publication writes a
  model, and the server keeps every model it gets.

  The boot attaches the handler either way. The handler writes a marker on
  the connection the change ran on. So it needs a binding and the write's
  own transaction, and no tree of this application's.
  """

  use Application

  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.Siem
  alias Mediate.Fga.Binding
  alias Mediate.Fga.Outbox

  @impl Application
  def start(_type, _args) do
    _config = Mediate.Config.boot!(adapter: {Mediate.Fga, entry()})

    _binding =
      Binding.bind!(
        repo: Repo,
        model: ExampleFga.model(),
        mapping: ExampleFga.Infrastructure.TupleMapping,
        guard: ExampleFga.Infrastructure.Guard,
        author: ExampleFga.author(),
        approval: ExampleFga.approval()
      )

    :ok = Outbox.attach()
    started = started()
    children = [{Siem, name: Siem, attach: true} | started]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExampleFga.Supervisor) do
      :ok = publish(started)
      {:ok, pid}
    end
  end

  # Where the server is, and which store holds this application's tuples.
  # How far the drain has got is the cursor's, in the database, and not the
  # configuration's.
  defp entry do
    [
      endpoint: Application.fetch_env!(:example_fga, :endpoint),
      store_id: Application.fetch_env!(:example_fga, :store_id)
    ]
  end

  # A publication writes a model to the server, so it belongs to whoever
  # raises the tree: this one, or the test helper.
  defp publish([]), do: :ok

  defp publish(_children) do
    {:ok, _published} = Mediate.Fga.publish()
    :ok
  end

  defp started do
    if Application.get_env(:example_fga, :start_repos, true) do
      [Repo, Example.Infrastructure.OwnerRepo, drain()]
    else
      []
    end
  end

  defp drain do
    {Mediate.Fga.Relay, runners: [[name: Outbox.runner(), repo: Repo, job: Outbox]]}
  end
end
