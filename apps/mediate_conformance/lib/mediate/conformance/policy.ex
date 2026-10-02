defmodule Mediate.Conformance.Policy do
  @moduledoc """
  What the `cm3` requirements need and a procedure cannot write without
  the engine's name. It says how this engine releases a policy version,
  how to tighten a rule on it, and how to put the original back. The test
  passes it to `Mediate.Conformance.EngineCase` as `policy:`. A case given
  none runs the `cm3` requirements as skipped and prints the reason.

  The procedures measure the release latency against the tightened
  version. After `tighten/0`, the engine denies the grantee of the granted
  world the first action the world knows. `restore/0` puts the original
  rule back and returns once it is in force again, because the next
  procedure asks with no poll of its own.

  These procedures write on the durable repo. On some engines a release is
  a statement the sandbox's transaction blocks.
  """

  alias Mediate.PolicyRelease

  @doc "Release a version that excludes the grantee from a read, and answer that release."
  @callback tighten() :: {:ok, PolicyRelease.t()} | {:error, Mediate.Error.t()}

  @doc "Put the original rule back, and return once it is in force."
  @callback restore() :: :ok

  @doc "Prepare an engine that keeps state per test, given the test's tags."
  @callback setup(map()) :: :ok

  @optional_callbacks setup: 1
end
