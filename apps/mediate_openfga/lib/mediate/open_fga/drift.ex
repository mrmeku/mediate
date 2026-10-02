defmodule Mediate.OpenFGA.Drift do
  @moduledoc """
  What a reconcile found:

  - the tuples the tables require and the store lacks
  - the tuples the store holds and no table requires
  - the position of the last marker the runner had delivered at the comparison

  An empty drift says the store and the tables agree. A drift that is not
  empty says where they differ, tuple by tuple. So an operator reads what
  to repair and not a count. A marker written while the comparison ran is
  above the position. That is what says how current an empty answer is.
  """

  alias Mediate.OpenFGA.TupleKey

  @enforce_keys [:missing, :extra, :position]
  defstruct @enforce_keys

  @typedoc "What one reconcile found."
  @type t :: %__MODULE__{
          missing: [TupleKey.t()],
          extra: [TupleKey.t()],
          position: non_neg_integer()
        }

  @doc "Whether nothing differs."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{missing: [], extra: []}), do: true
  def empty?(%__MODULE__{}), do: false
end
