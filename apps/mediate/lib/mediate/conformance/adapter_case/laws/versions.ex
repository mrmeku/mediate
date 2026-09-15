defmodule Mediate.Conformance.AdapterCase.Laws.Versions do
  @moduledoc """
  The bodies of the change-management laws, `cm3-01` to `cm3-04`, over the
  `Mediate.Conformance.Versions` module the template got. They assert:

  - what the publication of a version emits
  - what a decision reports before and after
  - what a tightened rule is
  - how long it takes to be in force

  Each restores the original rule before it returns, whatever it
  asserted, so the next test starts from the boot rules. Each is a
  function of the test context, as `Mediate.Conformance.AdapterCase.Laws`
  describes.
  """

  import ExUnit.Assertions

  alias Mediate.Conformance.AdapterCase.Laws
  alias Mediate.Decision
  alias Mediate.Id
  alias Mediate.PolicyVersion
  alias Mediate.Test

  @deadline 30_000
  @named ~w(version content_hash author approval)a

  @doc "`cm3-01`: a tighten publishes one version event with the version, which names its author and approval."
  @spec publish(Laws.context()) :: :ok
  def publish(%{case: %{versions: versions}}) do
    event = versions.event()
    handler = :telemetry_test.attach_event_handlers(self(), [event])

    try do
      assert {:ok, %PolicyVersion{} = version} = versions.tighten()
      assert_receive {^event, ^handler, _measurements, %{version: ^version}}
      assert_named(version)
    after
      :telemetry.detach(handler)
      :ok = versions.restore()
    end

    :ok
  end

  @doc """
  `cm3-02`: the decision before the tighten reports the boot version. The
  tightened version differs from it. The first denial after the tighten
  reports the tightened version.
  """
  @spec version_reported(Laws.context()) :: :ok
  def version_reported(%{case: %{versions: versions, world: module}} = context) do
    {_world, subject, _grantable, object, operation} = Laws.granted_focus(context, module)

    assert {:ok, %Decision{policy_version: before}} = Mediate.authorize(subject, operation, object)
    assert is_binary(before)

    try do
      assert {:ok, %PolicyVersion{} = next} = versions.tighten()
      refute next.version == before
      assert_denied_under(subject, operation, object, next.version)
    after
      :ok = versions.restore()
    end

    :ok
  end

  @doc """
  `cm3-03`: the tightened rule is a version that names its artifact, as
  content or as a pointer. Under it the port denies the reader.
  """
  @spec tightened_artifact(Laws.context()) :: :ok
  def tightened_artifact(%{case: %{versions: versions, world: module}} = context) do
    {_world, subject, _grantable, object, operation} = Laws.granted_focus(context, module)

    try do
      assert {:ok, %PolicyVersion{} = next} = versions.tighten()
      assert_named(next)
      assert_denied_under(subject, operation, object, next.version)
    after
      :ok = versions.restore()
    end

    :ok
  end

  @doc "`cm3-04`: after the tighten the port denies the reader. The law prints the time to the first denial and never asserts it."
  @spec propagation(Laws.context()) :: true
  def propagation(%{case: %{versions: versions, adapter: adapter, world: module}} = context) do
    {_world, subject, _grantable, object, operation} = Laws.granted_focus(context, module)
    started = System.monotonic_time(:millisecond)

    try do
      assert {:ok, %PolicyVersion{} = version} = versions.tighten()
      published = System.monotonic_time(:millisecond)
      assert Test.poll(fn -> not Mediate.check(subject, operation, object) end, @deadline)
      denied = System.monotonic_time(:millisecond)

      Laws.report("""
      propagation latency, #{inspect(adapter)}, version #{version.version}: total #{denied - started} ms
        publish #{published - started} ms
        poll #{denied - published} ms, floor #{Test.poll_interval()} ms
      """)
    after
      :ok = versions.restore()
    end

    assert Test.poll(fn -> Mediate.check(subject, operation, object) end, @deadline)
  end

  # The version names what a change record needs: the version, the hash of
  # its content, who wrote it, and who approved it. It carries the content
  # itself or a pointer to where it is.
  defp assert_named(%PolicyVersion{} = version) do
    Enum.each(@named, fn key ->
      value = Map.fetch!(version, key)
      assert is_binary(value) and value != "", "the policy version carries no #{key}: #{inspect(version)}"
    end)

    assert is_binary(version.content) or is_binary(version.pointer)
  end

  defp assert_denied_under(subject, operation, object, version) do
    assert Test.poll(fn -> not Mediate.check(subject, operation, object) end, @deadline)
    id = Id.new()
    {allowed?, events} = Laws.recorded(fn -> Mediate.check(subject, operation, object, operation_id: id) end)
    refute allowed?
    assert [%{verdict: :deny, version: ^version, operation_id: ^id}] = events
  end
end
