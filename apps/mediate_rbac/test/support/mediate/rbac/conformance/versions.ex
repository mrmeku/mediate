defmodule Mediate.Rbac.Conformance.Versions do
  @moduledoc """
  The change-management artifact of RBAC in code (`docs/conformance.md`
  §4). `tighten/0` binds `Mediate.Rbac.Conformance.Tightened` in place of
  the boot role table and publishes it. `restore/0` binds the boot table
  again. A policy in code is in force the moment the adapter binds it, so
  neither waits.
  """

  @behaviour Mediate.Conformance.Versions

  alias Mediate.Conformance.Versions
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Roles
  alias Mediate.Rbac.Conformance.Tightened
  alias Mediate.Rbac.Version

  @impl Versions
  def event, do: Version.telemetry_event()

  @impl Versions
  def tighten do
    :ok = Binding.override(policy: Tightened)
    Mediate.Rbac.publish()
  end

  @impl Versions
  def restore, do: Binding.override(policy: Roles)
end
