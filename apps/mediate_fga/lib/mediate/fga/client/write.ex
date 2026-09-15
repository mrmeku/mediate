defmodule Mediate.Fga.Client.Write do
  @moduledoc """
  The tuples one call deletes and the tuples it writes. The server applies
  them together or not at all. It counts them against one limit, and it
  refuses a key that appears on both sides. So a caller states both lists
  and keeps each call under `Mediate.Fga.Client.max_tuples_per_write/0`.
  """

  alias Mediate.Fga.TupleKey

  @enforce_keys [:deletes, :writes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{deletes: [TupleKey.t()], writes: [TupleKey.t()]}
end
