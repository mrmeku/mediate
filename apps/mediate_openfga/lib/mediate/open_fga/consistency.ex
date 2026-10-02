defmodule Mediate.OpenFGA.Consistency do
  @moduledoc """
  What a call asks of the store's replication. `:minimize_latency` takes
  what is at hand. `:higher_consistency` waits for the last write.
  `:unspecified` leaves the choice to the server's own default.

  Which one a callback takes is a constant of this engine and not an
  option a deployment sets. So the field on a request carries the choice,
  and no caller passes it in.
  """

  @typedoc "The three the server knows."
  @type t :: :unspecified | :minimize_latency | :higher_consistency
end
