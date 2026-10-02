defmodule Mediate.Conformance.Reference.Policy do
  @moduledoc """
  The fake engine's policy. `tighten/0` takes the grantee's first action
  on the granted world's target out of the fake's rule table and releases
  the version `tightened`. `restore/0` puts the entry back and releases
  the version `restored`, because an engine cannot take a release back.
  The fake's table is in force the moment it changes, so neither waits.
  """

  @behaviour Mediate.Conformance.Policy

  alias Mediate.Conformance.Policy
  alias Mediate.Conformance.Reference.Mirror
  alias Mediate.Conformance.Reference.World
  alias Mediate.Test.Fake

  @impl Policy
  def tighten do
    rules = Mirror.rules!()
    {subject, action, resource} = excluded()
    :ok = Fake.revoke(rules, subject, action, resource)
    Fake.release(rules, "tightened")
  end

  @impl Policy
  def restore do
    rules = Mirror.rules!()
    {subject, action, resource} = excluded()
    :ok = Fake.allow(rules, subject, action, resource)
    {:ok, _release} = Fake.release(rules, "restored")
    :ok
  end

  # The grant the tightened version excludes: the one the granted world holds.
  defp excluded do
    world = World.granted()
    {subject, target} = World.grantee(world)
    {subject, hd(World.actions()), World.resource(target)}
  end
end
