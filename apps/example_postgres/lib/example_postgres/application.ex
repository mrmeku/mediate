defmodule ExamplePostgres.Application do
  @moduledoc """
  The boot of the example under row-level security. It does four things in
  order:

  - the configuration names the engine
  - the binding names the repo and the schemas whose tables the rules
    protect and read
  - the supervisor starts the repos and the security log consumer
  - the catalog load follows, once the tree is up

  The test configuration leaves the repos to the run's cluster, and with
  them the catalog load. The catalog is a query, which needs a repo to run
  through.
  """

  use Application

  alias Example.Infrastructure.OwnerRepo
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.SIEM
  alias ExamplePostgres.Infrastructure.Policy
  alias Mediate.Postgres.Binding

  @impl Application
  def start(_type, _args) do
    _config = Mediate.Config.boot!(engine: Mediate.Postgres)
    _binding = Binding.bind!(repo: Repo, schemas: Policy.schemas())
    repos = repos()
    children = [{SIEM, name: SIEM, attach: true} | repos]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExamplePostgres.Supervisor) do
      :ok = load_catalog(repos)
      {:ok, pid}
    end
  end

  # The catalog load belongs to whoever starts the repos: this tree, or the
  # run's cluster.
  defp load_catalog([]), do: :ok

  defp load_catalog(_repos) do
    _catalog = Mediate.Postgres.load_catalog!()
    :ok
  end

  defp repos do
    if Application.get_env(:example_postgres, :start_repos, true), do: [Repo, OwnerRepo], else: []
  end
end
