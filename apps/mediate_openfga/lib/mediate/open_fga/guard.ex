defmodule Mediate.OpenFGA.Guard do
  @moduledoc """
  A precondition on the context, which the engine asks before any
  question goes to the server. Where the binding names a guard, every
  callback consults it first. The engine denies an action the guard does
  not admit where it stands, and asks the store nothing.

  This is where a fact about the call belongs that no tuple must carry.
  The server evaluates a condition on a tuple against the context of
  every question that walks that tuple. So a fact one action needs
  becomes a fact every use of the relation demands, and a question
  without it fails and does not answer. A guard keeps such a fact on this
  side of the call, where the engine knows the action it applies to.

  The engine asks a guard with the action and the context alone. It sees
  no subject and no resource. A precondition that depends on either is a
  rule of the model, where the graph can walk it.
  """

  @doc """
  Whether the guard admits this action under this context. A guard
  answers a boolean and nothing else. A guard that cannot tell is a guard
  that does not admit.
  """
  @callback admits?(action :: atom(), context :: Mediate.context()) :: boolean()
end
