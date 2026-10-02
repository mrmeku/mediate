defmodule Mediate.Conformance.Procedure.Change do
  @moduledoc """
  The procedures of the change-management requirements, `cm3-01` to
  `cm3-04`, over the `Mediate.Conformance.Policy` module the case got.
  They assert:

  - what the release of a policy version emits
  - what a decision reports before and after
  - what a tightened rule is
  - how long it takes to be in force

  Each restores the original rule before it returns, whatever it
  asserted, so the next test starts from the boot rules. Each is a
  function of the test context, as `Mediate.Conformance.Procedure`
  describes.
  """

  import ExUnit.Assertions

  alias Mediate.Conformance.Procedure
  alias Mediate.Decision
  alias Mediate.Id
  alias Mediate.PolicyRelease
  alias Mediate.Test

  @deadline 30_000
  @named ~w(policy_version text_hash author approval)a

  @doc "`cm3-01`: a tighten emits one policy release event with the release, which names its author and approval."
  @spec cm3_01(Procedure.context()) :: :ok
  def cm3_01(%{conformance: %{policy: policy}}) do
    event = PolicyRelease.event()
    handler = :telemetry_test.attach_event_handlers(self(), [event])

    try do
      assert {:ok, %PolicyRelease{} = release} = policy.tighten()
      assert_receive {^event, ^handler, _measurements, %{release: ^release}}
      assert_named(release)
    after
      :telemetry.detach(handler)
      :ok = policy.restore()
    end

    :ok
  end

  @doc """
  `cm3-02`: the decision before the tighten reports the boot version. The
  tightened version differs from it. The first denial after the tighten
  reports the tightened version.
  """
  @spec cm3_02(Procedure.context()) :: :ok
  def cm3_02(%{conformance: %{policy: policy, world: module}} = context) do
    {_world, subject, _target, resource, action} = Procedure.granted(context, module)

    assert {:ok, %Decision{policy_version: before}} = Mediate.authorize(subject, action, resource)
    assert is_binary(before)

    try do
      assert {:ok, %PolicyRelease{} = next} = policy.tighten()
      refute next.policy_version == before
      assert_denied_under(subject, action, resource, next.policy_version)
    after
      :ok = policy.restore()
    end

    :ok
  end

  @doc """
  `cm3-03`: the tightened rule is a release that carries its text, by
  value or by location. Under it the library denies the reader.
  """
  @spec cm3_03(Procedure.context()) :: :ok
  def cm3_03(%{conformance: %{policy: policy, world: module}} = context) do
    {_world, subject, _target, resource, action} = Procedure.granted(context, module)

    try do
      assert {:ok, %PolicyRelease{} = next} = policy.tighten()
      assert_named(next)
      assert_denied_under(subject, action, resource, next.policy_version)
    after
      :ok = policy.restore()
    end

    :ok
  end

  @doc "`cm3-04`: after the tighten the library denies the reader. The procedure prints the time to the first denial and never asserts it."
  @spec cm3_04(Procedure.context()) :: true
  def cm3_04(%{conformance: %{policy: policy, engine: engine, world: module}} = context) do
    {_world, subject, _target, resource, action} = Procedure.granted(context, module)
    started = System.monotonic_time(:millisecond)

    try do
      assert {:ok, %PolicyRelease{} = release} = policy.tighten()
      released = System.monotonic_time(:millisecond)
      assert Test.poll(fn -> not Mediate.authorized?(subject, action, resource) end, @deadline)
      denied = System.monotonic_time(:millisecond)

      Procedure.report("""
      release latency, #{inspect(engine)}, version #{release.policy_version}: total #{denied - started} ms
        release #{released - started} ms
        poll #{denied - released} ms, floor #{Test.poll_interval()} ms
      """)
    after
      :ok = policy.restore()
    end

    assert Test.poll(fn -> Mediate.authorized?(subject, action, resource) end, @deadline)
  end

  # The release names what a change record needs: the version, the hash of
  # its text, who wrote it, and who approved it. It carries the text
  # itself or the location it lives at.
  defp assert_named(%PolicyRelease{} = release) do
    Enum.each(@named, fn key ->
      value = Map.fetch!(release, key)
      assert is_binary(value) and value != "", "the policy release carries no #{key}: #{inspect(release)}"
    end)

    assert is_binary(release.text) or is_binary(release.text_location)
  end

  defp assert_denied_under(subject, action, resource, policy_version) do
    assert Test.poll(fn -> not Mediate.authorized?(subject, action, resource) end, @deadline)
    id = Id.new()

    {allowed?, events} =
      Procedure.decisions(fn -> Mediate.authorized?(subject, action, resource, correlation_id: id) end)

    refute allowed?
    assert [%{effect: :deny, policy_version: ^policy_version, correlation_id: ^id}] = events
  end
end
