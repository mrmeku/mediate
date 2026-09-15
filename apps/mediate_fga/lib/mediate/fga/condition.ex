defmodule Mediate.Fga.Condition do
  @moduledoc """
  A condition on a tuple: the name of a condition the model declares, and
  the context its parameters take. The server evaluates it against the
  context a check sends. That is how a date, a clearance, or any other
  parameter reaches a decision without a tuple per value.

  A condition is a value the tuple carries and no part of the tuple's key.
  So the same tuple with another context is that tuple changed and not a
  second one.
  """

  @enforce_keys [:name]
  defstruct [:name, context: %{}]

  @typedoc "The condition's name in the model, and the parameters it carries by name."
  @type t :: %__MODULE__{name: String.t(), context: %{String.t() => term()}}
end
