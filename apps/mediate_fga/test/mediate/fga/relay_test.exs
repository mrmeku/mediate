defmodule Mediate.Fga.RelayTest do
  use ExUnit.Case, async: false

  alias Mediate.Dev.Sandbox
  alias Mediate.Fga.Relay
  alias Mediate.Fga.Relay.Cursor
  alias Mediate.Fga.Relay.Infrastructure.Drain
  alias Mediate.Fga.Relay.Options
  alias Mediate.Fga.Relay.Pass
  alias Mediate.Fga.Relay.TestJob
  alias Mediate.TestRepos.Sandboxed

  # One pair of names for every test in this module. Each runs in a
  # transaction of its own, and the test stops the processes with it.
  @runner :rooted
  @other :rooted_other

  setup tags do
    :ok = Sandbox.setup(Sandboxed, tags)
    {:ok, runner: @runner}
  end

  test "the options a runner takes are the ones the package publishes" do
    assert Relay.options_schema() == Options.schema()
  end

  test "a supervisor starts one process per runner, each woken by its own name", %{runner: runner} do
    other = @other
    :ok = attach(runner)
    supervisor = start_supervised!({Relay, name: RootSupervisor, runners: [runner(runner), runner(other)]})

    assert Supervisor.count_children(supervisor).active == 2
    assert is_pid(Process.whereis(runner))
    assert is_pid(Process.whereis(other))

    assert Relay.wake(runner) == :ok
    assert_receive {:pass, %{delivered: 0}}, 5_000
  end

  test "a drain asked for at the root delivers what a runner's tick would", %{runner: runner} do
    :ok = TestJob.write(Sandboxed, Atom.to_string(runner), 3)

    assert {:ok, %Pass{delivered: 3} = pass} = Relay.drain_once(runner(runner))
    assert Cursor.position(Sandboxed, runner) == pass.position
  end

  defp attach(runner) do
    handler = "relay-test-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler,
        Drain.event(),
        fn _event, measurements, %{name: name}, {pid, watched} ->
          if name == watched, do: send(pid, {:pass, measurements})
        end,
        {parent, runner}
      )

    on_exit(fn -> :telemetry.detach(handler) end)
  end

  defp runner(name) do
    [
      name: name,
      repo: Sandboxed,
      job: TestJob,
      job_options: [runner: Atom.to_string(name)],
      first: 60_000,
      idle: 60_000
    ]
  end
end
