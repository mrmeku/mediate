defmodule ExampleRbac.ApplicationTest do
  # Not async: the application restarts here, after every async test has run.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Example.Infrastructure.SIEM
  alias ExampleRbac.Infrastructure.Policy
  alias Mediate.Config
  alias Mediate.Rbac.Binding

  test "the application boots, binds and releases again after a restart" do
    _stopped = capture_log(fn -> :ok = Application.stop(:example_rbac) end)
    refute Process.whereis(ExampleRbac.Supervisor)
    refute Process.whereis(SIEM)

    _started = capture_log(fn -> assert {:ok, [:example_rbac]} = Application.ensure_all_started(:example_rbac) end)
    assert Process.alive?(Process.whereis(ExampleRbac.Supervisor))
    assert Process.alive?(Process.whereis(SIEM))

    assert {:ok, %Config{} = config} = Config.resolve()
    assert Config.engine(config) == {Mediate.Rbac, []}
    assert {:ok, %Binding{policy: Policy, repo: Example.Infrastructure.Repo}} = Binding.resolve()
  end
end
