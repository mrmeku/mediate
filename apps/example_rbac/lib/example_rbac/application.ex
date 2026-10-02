defmodule ExampleRbac.Application do
  @moduledoc """
  The boot of the example under roles in code. It does four things in order:

  - the configuration names the engine
  - the binding names the policy module and the repo
  - the supervisor starts the repos and the security log consumer
  - the policy release is published once the tree is up

  The test configuration leaves the repos to the run's cluster, and with
  them the policy release. So a run has one policy release rather than two.
  """

  use Application

  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.SIEM
  alias Mediate.Rbac.Binding

  @impl Application
  def start(_type, _args) do
    _config = Mediate.Config.boot!(engine: Mediate.Rbac)
    _binding = Binding.bind!(policy: ExampleRbac.Infrastructure.Policy, repo: Repo)
    repos = repos()
    children = [{SIEM, name: SIEM, attach: true} | repos]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExampleRbac.Supervisor) do
      :ok = release(repos)
      {:ok, pid}
    end
  end

  # The policy release belongs to whoever starts the repos: this tree, or the
  # test cluster.
  defp release([]), do: :ok

  defp release(_repos) do
    {:ok, _release} = Mediate.Rbac.release()
    :ok
  end

  defp repos do
    if Application.get_env(:example_rbac, :start_repos, true), do: [Repo, Example.Infrastructure.OwnerRepo], else: []
  end
end
