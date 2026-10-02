defmodule Mediate.OpenFGA.Client.Read do
  @moduledoc """
  Tuples as the store holds them. No decision consults them. A pass and a
  reconcile both do. The object type must be present, because that is
  the unit the store pages by. An object id narrows it to one object, and
  a relation or a user narrows it further.

  `page_size` is how many tuples one page holds. `continuation_token` is
  what the previous page answered with. So a caller reads to the end when
  it asks again until the token is nothing.
  """

  @enforce_keys [:object_type]
  defstruct [:object_type, :object_id, :relation, :user, :continuation_token, page_size: 100]

  @typedoc "One read request."
  @type t :: %__MODULE__{
          object_type: String.t(),
          object_id: String.t() | nil,
          relation: String.t() | nil,
          user: String.t() | nil,
          continuation_token: String.t() | nil,
          page_size: pos_integer()
        }
end
