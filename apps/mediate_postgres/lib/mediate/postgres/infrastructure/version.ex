defmodule Mediate.Postgres.Infrastructure.Version do
  @moduledoc false
  # The publication of a policy version: one telemetry event per call, with
  # the version in it. The publication stores nothing, so the event is the
  # whole of what it leaves behind. The event's name lives here, beside the
  # one place that emits it. What a version is, and what it holds, belongs
  # to `Mediate.Postgres.Version`.

  alias Mediate.PolicyVersion

  @telemetry [:mediate, :postgres, :policy_version]

  @doc "The event `publish/1` emits, which `Mediate.Postgres.Version.telemetry_event/0` answers with."
  @spec telemetry_event() :: [atom()]
  def telemetry_event, do: @telemetry

  @doc "Emit the version once per call, and answer the version it emitted."
  @spec publish(PolicyVersion.t()) :: {:ok, PolicyVersion.t()}
  def publish(%PolicyVersion{} = version) do
    :telemetry.execute(@telemetry, %{}, %{version: version})

    {:ok, version}
  end
end
