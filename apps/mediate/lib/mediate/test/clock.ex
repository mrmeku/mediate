defmodule Mediate.Test.Clock do
  @moduledoc """
  The clock a test sets. `set/1` overrides the configured clock for the rest
  of the current process and answers the moment it set. So a test that
  needs a fixed time names it once, and every call the port makes reads it.

  The configured clock is a zero-arity function, so a test needs no mock
  and no behaviour of its own. `set/1` installs a closure over the moment.
  `Mediate.Config.resolve/0` finds it from the test process and from any
  process in its `$callers` chain.
  """

  @doc "Set the clock for the rest of the current process, and answer the moment."
  @spec set(DateTime.t()) :: DateTime.t()
  def set(%DateTime{} = at) do
    :ok = Mediate.Test.with_config(clock: fn -> at end)
    at
  end
end
