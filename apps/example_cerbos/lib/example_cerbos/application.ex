defmodule ExampleCerbos.Application do
  @moduledoc """
  The boot of the example under policy files. It does four things in order:

  - the configuration names the engine and the server's address
  - the binding names the repo, the declarations, the policy directory, and
    the commit that directory is at
  - the supervisor starts the security log consumer and the repos
  - the policy release follows, once the tree is up

  The test configuration leaves the repos to the run's cluster, and with
  them the release. So a run has one policy release and not two.
  """

  use Application

  alias Example.Infrastructure.OwnerRepo
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.SIEM
  alias ExampleCerbos.Infrastructure.Declarations
  alias Mediate.Cerbos.Binding

  @impl Application
  def start(_type, _args) do
    address = Application.fetch_env!(:example_cerbos, :address)
    _config = Mediate.Config.boot!(engine: {Mediate.Cerbos, address: address})

    _binding =
      Binding.bind!(
        repo: Repo,
        declarations: Declarations,
        policy_dir: policy_dir(),
        commit: Application.fetch_env!(:example_cerbos, :commit),
        author: ExampleCerbos.author(),
        approval: ExampleCerbos.approval()
      )

    repos = repos()
    children = [{SIEM, name: SIEM, attach: true} | repos]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExampleCerbos.Supervisor) do
      :ok = release(repos)
      {:ok, pid}
    end
  end

  # A relative policy directory resolves under this application's priv
  # directory, so a release finds the files where the install put them.
  defp policy_dir do
    configured = Application.fetch_env!(:example_cerbos, :policy_dir)

    case Path.type(configured) do
      :absolute -> configured
      _relative -> Application.app_dir(:example_cerbos, configured)
    end
  end

  # The policy release belongs to whoever starts the repos: this tree, or
  # the run's cluster.
  defp release([]), do: :ok

  defp release(_repos) do
    {:ok, _release} = Mediate.Cerbos.release()
    :ok
  end

  defp repos do
    if Application.get_env(:example_cerbos, :start_repos, true), do: [Repo, OwnerRepo], else: []
  end
end
