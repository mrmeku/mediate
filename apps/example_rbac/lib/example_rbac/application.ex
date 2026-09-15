defmodule ExampleRbac.Application do
  @moduledoc """
  The boot of the example under RBAC in code. It does four things in order:

  - the configuration names the adapter
  - the binding names the policy and the repo
  - the supervisor starts the repos and the consumer of the events
  - the publish emits the policy version once the tree is up

  The test configuration leaves the repos to the ephemeral cluster, and with
  them the publish. So a run has one policy-version event rather than two.
  """

  use Application

  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.Siem
  alias Mediate.Rbac.Binding

  @impl Application
  def start(_type, _args) do
    _config = Mediate.Config.boot!(adapter: Mediate.Rbac)
    _binding = Binding.bind!(policy: ExampleRbac.Infrastructure.Policy, repo: Repo)
    repos = repos()
    children = [{Siem, name: Siem, attach: true} | repos]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExampleRbac.Supervisor) do
      :ok = publish(repos)
      {:ok, pid}
    end
  end

  # The publish belongs to whoever starts the repos: this tree, or the test
  # cluster.
  defp publish([]), do: :ok

  defp publish(_repos) do
    {:ok, _published} = Mediate.Rbac.publish()
    :ok
  end

  defp repos do
    if Application.get_env(:example_rbac, :start_repos, true), do: [Repo, Example.Infrastructure.OwnerRepo], else: []
  end
end
