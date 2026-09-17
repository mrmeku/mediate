defmodule Mediate.Fga.Relay.Pass do
  @moduledoc """
  What one pass did:

  - whether it held the lock
  - how many entries it delivered
  - where its cursor stands
  - whether the batch was full
  - the moment it finished, from the clock in the runner's options

  `more?` is what the runner reads to decide whether to pass again at once.
  A full batch means the rows that follow it are already there.
  """

  @enforce_keys [:name, :held?, :delivered, :position, :more?, :at]
  defstruct @enforce_keys

  @typedoc "What one pass did."
  @type t :: %__MODULE__{
          name: atom(),
          held?: boolean(),
          delivered: non_neg_integer(),
          position: non_neg_integer(),
          more?: boolean(),
          at: DateTime.t()
        }
end
