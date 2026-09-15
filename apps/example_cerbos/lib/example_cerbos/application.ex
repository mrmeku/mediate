defmodule ExampleCerbos.Application do
  @moduledoc """
  The boot of the example under the sidecar.

  The boot does these things, in order:

  - The configuration names the sidecar's address.
  - The binding names the repo, the attribute declarations, the policy
    directory, and the commit that directory is at.
  - The supervisor starts the consumer of the events and the repos.
  - Once the tree is up, the boot publishes the commit as a policy version.

  The test configuration leaves the repos to the ephemeral cluster, and with
  them the publish. So a run has one policy-version event and not two.
  """

  use Application

  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.Siem
  alias Mediate.Cerbos.Binding

  @impl Application
  def start(_type, _args) do
    address = Application.fetch_env!(:example_cerbos, :address)
    _config = Mediate.Config.boot!(adapter: {Mediate.Cerbos, address: address})

    _binding =
      Binding.bind!(
        repo: Repo,
        attributes: ExampleCerbos.Infrastructure.Attributes,
        policies: policies(),
        commit: Application.fetch_env!(:example_cerbos, :commit),
        author: ExampleCerbos.author(),
        approval: ExampleCerbos.approval()
      )

    repos = repos()
    children = [{Siem, name: Siem, attach: true} | repos]

    with {:ok, pid} <- Supervisor.start_link(children, strategy: :one_for_one, name: ExampleCerbos.Supervisor) do
      :ok = publish(repos)
      {:ok, pid}
    end
  end

  # A relative policy directory resolves under this application's priv
  # directory, so a release finds the files where the install put them.
  defp policies do
    configured = Application.fetch_env!(:example_cerbos, :policies)

    case Path.type(configured) do
      :absolute -> configured
      _relative -> Application.app_dir(:example_cerbos, configured)
    end
  end

  # The publish belongs to whoever starts the repos: this tree, or the test
  # cluster.
  defp publish([]), do: :ok

  defp publish(_repos) do
    {:ok, _published} = Mediate.Cerbos.publish()
    :ok
  end

  defp repos do
    if Application.get_env(:example_cerbos, :start_repos, true), do: [Repo, Example.Infrastructure.OwnerRepo], else: []
  end
end
