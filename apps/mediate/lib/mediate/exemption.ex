defmodule Mediate.Exemption do
  @moduledoc """
  A named, logged opt-out from mediation, per call. One the caller declared
  carries the caller's justification. One the library declared marks the
  mediated repo's own writes, and the repo accepts it only from a
  `Mediate.*` module.
  """

  @enforce_keys [:source, :caller, :justification, :declared_by]
  defstruct @enforce_keys

  @typedoc "Who declared the opt-out: the caller, or the library itself."
  @type declared_by :: :caller | :library

  @typedoc "`source` is the root source: a schema module, a table name, or `nil` for raw SQL."
  @type t :: %__MODULE__{
          source: module() | String.t() | nil,
          caller: module() | :any,
          justification: String.t(),
          declared_by: declared_by()
        }
end
