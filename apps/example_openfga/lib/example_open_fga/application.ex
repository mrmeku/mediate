defmodule ExampleOpenFGA.Application do
  @moduledoc """
  The boot of the example under OpenFGA. It does five things in order:

  - the configuration names the engine, the server's address, and the store
  - the binding names the repo the markers and the tables are read through,
    the model file, the mapping, and the guard
  - the boot attaches the handler that writes a marker for every change
  - the supervisor starts the security log consumer, the repos, and the
    relay whose runner delivers the markers
  - the policy release follows, once the tree is up

  The runner passes over the outbox on its interval. It starts here and not
  in a test. A test syncs the store itself, and a runner beside it reads the
  same markers from a connection of its own. So the test configuration
  leaves the repos to the run's cluster, the runner to the tests, and with
  them the release. A release writes a model, and the server keeps every
  model it gets.

  The boot attaches the handler either way. The handler writes a marker on
  the connection the change ran on. So it needs a binding and the write's
  own transaction, and no tree of this application's.
  """

  use Application

  alias Example.Infrastructure.OwnerRepo
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.SIEM
  alias ExampleOpenFGA.Infrastructure.Guard
  alias ExampleOpenFGA.Infrastructure.Mapping
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Outbox

  @impl Application
  def start(_type, _args) do
    _config = Mediate.Config.boot!(engine: {Mediate.OpenFGA, engine()})

    _binding =
      Binding.bind!(
        repo: Repo,
        model_file: ExampleOpenFGA.model_file(),
        mapping: Mapping,
        guard: Guard,
        author: ExampleOpenFGA.author(),
        approval: ExampleOpenFGA.approval()
      )

    :ok = Outbox.attach()
    children = children()

    with {:ok, pid} <-
           Supervisor.start_link([{SIEM, name: SIEM, attach: true} | children],
             strategy: :one_for_one,
             name: ExampleOpenFGA.Supervisor
           ) do
      :ok = release(children)
      {:ok, pid}
    end
  end

  # Where the server is, and which store holds this application's tuples.
  # How far the runner has got is the cursor's, in the database, and not
  # the configuration's.
  defp engine do
    [
      address: Application.fetch_env!(:example_openfga, :address),
      store_id: Application.fetch_env!(:example_openfga, :store_id)
    ]
  end

  # The policy release belongs to whoever starts the repos: this tree, or
  # the run's cluster.
  defp release([]), do: :ok

  defp release(_children) do
    {:ok, _release} = Mediate.OpenFGA.release()
    :ok
  end

  defp children do
    if Application.get_env(:example_openfga, :start_repos, true), do: [Repo, OwnerRepo, relay()], else: []
  end

  defp relay do
    {Mediate.Relay, runners: [[name: Outbox.runner(), repo: Repo, job: Outbox]]}
  end
end
