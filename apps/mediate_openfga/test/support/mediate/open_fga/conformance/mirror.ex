defmodule Mediate.OpenFGA.Conformance.Mirror do
  @moduledoc """
  How the conformance case makes this engine's store agree with a world
  (`Mediate.Conformance.Mirror`). The mirror marks every object and syncs,
  and writes nothing the world says itself. The case writes each world
  through the mediated repo, so the tables carry it already. So the sync is
  the mechanism under test and not a shortcut around it. Each object costs
  a read and the difference, so a world after a world writes only what
  changed.

  The mirror marks the objects itself and leaves none of it to the
  handler. The case counts the queries a write costs, and a handler that
  writes a marker inside that write is one more. What the handler does
  instead is `Mediate.OpenFGA.OutboxCase`'s to hold.
  """

  @behaviour Mediate.Conformance.Mirror

  alias Mediate.Conformance.Reference.World
  alias Mediate.OpenFGA

  @impl Mediate.Conformance.Mirror
  def mirror(%World{}) do
    :ok = OpenFGA.mark_all()
    OpenFGA.sync()
  end
end
