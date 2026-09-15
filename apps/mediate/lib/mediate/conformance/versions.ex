defmodule Mediate.Conformance.Versions do
  @moduledoc """
  What the `cm3` laws need and a law cannot write without the adapter's
  name. It says how this adapter publishes a policy version, how to
  tighten a rule on it, and how to put the original back. The test passes
  it to `Mediate.Conformance.AdapterCase` as `versions:`. A template given
  none runs the `cm3` laws as skipped and prints the reason.

  The laws measure propagation against the tightened version. After
  `tighten/0`, the adapter denies the subject `focus/1` of the granted
  world names the first operation the world knows. That subject holds an
  editor's grant. `restore/0` puts the original rule back and returns once
  it is in force again, because the next law asks with no poll of its own.

  These laws write on the committed repo. On some adapters a version is a
  statement the sandbox's transaction blocks.
  """

  alias Mediate.PolicyVersion

  @doc "The telemetry event the adapter publishes a policy version on."
  @callback event() :: [atom()]

  @doc "Publish a version that excludes the granted editor from a read, and answer that version."
  @callback tighten() :: {:ok, PolicyVersion.t()} | {:error, Mediate.Error.t()}

  @doc "Put the original rule back, and return once it is in force."
  @callback restore() :: :ok

  @doc "Prepare an engine that keeps state per test, given the test's tags."
  @callback setup(map()) :: :ok

  @optional_callbacks setup: 1
end
