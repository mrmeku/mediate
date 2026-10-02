defmodule Mediate.Rbac.Conformance.Policy do
  @moduledoc """
  The change-management artifact of roles in code
  (`Mediate.Conformance.Policy`). `tighten/0` binds
  `Mediate.Rbac.Conformance.Tightened` in place of the boot policy module
  and releases it. `restore/0` binds the boot module again. A policy in
  code is in force the moment the engine binds it, so neither waits.
  """

  @behaviour Mediate.Conformance.Policy

  alias Mediate.Conformance.Policy
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Conformance.Reference
  alias Mediate.Rbac.Conformance.Tightened

  @impl Policy
  def tighten do
    :ok = Binding.override(policy: Tightened)
    Mediate.Rbac.release()
  end

  @impl Policy
  def restore, do: Binding.override(policy: Reference)
end
