defmodule Mediate.Cerbos.Conformance.Outage do
  @moduledoc "The outage (`Mediate.Conformance.Outage`): the server is out of reach for the rest of the test."

  @behaviour Mediate.Conformance.Outage

  alias Mediate.Conformance.Outage
  alias Mediate.Test

  @impl Outage
  def disconnect, do: Test.with_config(engine: {Mediate.Cerbos, address: "127.0.0.1:1"})
end
