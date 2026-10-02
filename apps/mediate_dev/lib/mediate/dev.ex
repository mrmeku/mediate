defmodule Mediate.Dev do
  @moduledoc """
  The test tools of this repository. No adopter needs them.

  The modules under this name start the run's Postgres cluster, set up the
  sandbox, dump the structure file, and start the Cerbos and OpenFGA
  servers the suites ask for. This module holds the wait they share. No
  published package depends on this package outside its test environment.

  A published engine carries no dependency its own users have no use for.
  To start an operating-system process takes `muontrap`. So the modules
  that start the servers live here and not in the engine packages.
  """

  use Boundary, top_level?: true, deps: []

  @poll_timeout 5_000
  @poll_interval 10

  @doc """
  Calls `fun` until it returns a truthy value or `timeout` milliseconds pass.
  Returns the truthy value. Raises with the last value on timeout. This is
  the one place this package sleeps.
  """
  @spec poll!((-> term()), pos_integer()) :: term()
  def poll!(fun, timeout \\ @poll_timeout) when is_function(fun, 0) do
    deadline = System.monotonic_time(:millisecond) + timeout
    poll_until(fun, deadline, nil)
  end

  defp poll_until(fun, deadline, last) do
    case fun.() do
      falsy when falsy in [nil, false] ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "poll timed out; last value: #{inspect(last)}"
        else
          Process.sleep(@poll_interval)
          poll_until(fun, deadline, falsy)
        end

      value ->
        value
    end
  end
end
