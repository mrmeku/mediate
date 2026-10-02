defmodule Mediate.OpenFGA.Conformance.Outage do
  @moduledoc """
  The outage (`Mediate.Conformance.Outage`): the server is out of reach
  for the rest of the test. The entry keeps the store and the model it
  pins, so what changes is the address alone.
  """

  @behaviour Mediate.Conformance.Outage

  alias Mediate.Config
  alias Mediate.Conformance.Outage
  alias Mediate.OpenFGA
  alias Mediate.Test

  @impl Outage
  def disconnect do
    {:ok, %Config{} = config} = Config.resolve()
    {OpenFGA, options} = Config.engine(config)

    Test.with_config(engine: {OpenFGA, Keyword.put(options, :address, "127.0.0.1:1")})
  end
end
