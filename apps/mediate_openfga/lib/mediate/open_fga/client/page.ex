defmodule Mediate.OpenFGA.Client.Page do
  @moduledoc """
  One page of tuples and the token to ask for the next. A token of
  nothing is the last page. That is how a caller knows it has read an
  object whole.
  """

  alias Mediate.OpenFGA.TupleKey

  @enforce_keys [:tuples, :continuation_token]
  defstruct @enforce_keys

  @typedoc "One page of tuples, and the token to ask for the next."
  @type t :: %__MODULE__{tuples: [TupleKey.t()], continuation_token: String.t() | nil}
end
