defmodule Mediate.Cerbos.Conformance.Policy do
  @moduledoc """
  The change-management artifact of policy files
  (`Mediate.Conformance.Policy`). `tighten/0` writes the tightened folder
  policy over the one the server reads, binds the commit the tightened
  policy is at, and releases it. `restore/0` puts the boot file back,
  binds the boot commit, and asks the server until the boot policy
  answers again. The server watches its policy directory, so a swap is in
  force once the server has read the file. That wait is the release
  latency the requirements measure.
  """

  @behaviour Mediate.Conformance.Policy

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Client
  alias Mediate.Cerbos.Conformance.PolicyFiles
  alias Mediate.Cerbos.Request
  alias Mediate.Config
  alias Mediate.Conformance.Policy
  alias Mediate.Test

  @path "folder.yaml"
  @swapped {__MODULE__, :swapped}
  @deadline 30_000

  @impl Policy
  def tighten do
    {:ok, %Binding{} = binding} = Binding.resolve()
    previous = PolicyFiles.swap!(binding.policy_dir, [{@path, PolicyFiles.tightened()}])
    Process.put(@swapped, {binding.policy_dir, previous})
    :ok = Binding.override(commit: "conformance-tightened")
    Mediate.Cerbos.release()
  end

  @impl Policy
  def restore do
    {directory, previous} = Process.delete(@swapped)
    :ok = PolicyFiles.restore!(directory, previous)
    :ok = Binding.override(commit: "conformance")
    true = Test.poll(&editor_reads?/0, @deadline)
    :ok
  end

  # The boot policy is back once a cleared editor can read a folder again.
  # The question goes to the server with inline attributes, so it needs no
  # row.
  defp editor_reads? do
    {:ok, %Config{} = config} = Config.resolve()
    {Mediate.Cerbos, options} = Config.engine(config)
    principal = %{id: "mediate.restore", roles: ["user"], attr: %{clearance: "cleared"}}
    resource = %{kind: "folder", id: "0", attr: %{member_roles: ["editor"]}}

    case Client.check_resources(options[:address], Request.inline(principal, resource, ["read"])) do
      {:ok, %{"results" => [%{"actions" => %{"read" => "EFFECT_ALLOW"}}]}} -> true
      _other -> false
    end
  end
end
