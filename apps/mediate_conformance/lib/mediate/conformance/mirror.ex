defmodule Mediate.Conformance.Mirror do
  @moduledoc """
  How the engine case makes an engine agree with a world, for an engine
  whose state is not the world's own tables. `mirror/1` runs after every
  write of a world through the mediated repo. An engine that reads the
  tables needs no mirror module. The case gets one as `mirror:`.
  """

  alias Mediate.Conformance.World

  @doc "Make the engine's state agree with the world, from scratch."
  @callback mirror(World.t()) :: :ok
end
