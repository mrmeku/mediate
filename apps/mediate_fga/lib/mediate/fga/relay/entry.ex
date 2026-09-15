defmodule Mediate.Fga.Relay.Entry do
  @moduledoc """
  One row on its way out. The position orders it against every other row
  of the same runner. The payload is what the job read from its own table.
  What a payload holds is the job's, and the relay reads nothing in it.

  Positions rise and are unique within a runner. A `bigserial` column is
  the usual source of one, and any column a job can read from low to high
  serves.
  """

  @enforce_keys [:position, :payload]
  defstruct @enforce_keys

  @type t :: %__MODULE__{position: pos_integer(), payload: term()}
end
