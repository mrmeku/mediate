defmodule Mediate.Fga.Client.Read do
  @moduledoc """
  Tuples as the store holds them. No decision consults them. The drain and
  reconcile both do. The object type must be present, because that is the
  unit the store pages by. An object id narrows it to one object, and a
  relation or a user narrows it further.

  `limit` is how many tuples one page holds. `continuation` is what the
  previous page answered with. So a caller reads to the end when it asks
  again until the continuation is nothing.
  """

  @enforce_keys [:object_type]
  defstruct [:object_type, :object_id, :relation, :user, :continuation, limit: 100]

  @type t :: %__MODULE__{
          object_type: String.t(),
          object_id: String.t() | nil,
          relation: String.t() | nil,
          user: String.t() | nil,
          continuation: String.t() | nil,
          limit: pos_integer()
        }
end
