defmodule Mediate.Conformance.Outage do
  @moduledoc """
  How the engine case makes an engine unreachable. `disconnect/0` cuts the
  engine off for the rest of the test. The case gets one as `outage:`, and
  the fail-closed requirement, `ac3-05`, exists only for a case given one.
  """

  @doc "Make the engine unreachable for the rest of the test."
  @callback disconnect() :: :ok
end
