defmodule Mediate.Dev.CerbosSharedTest do
  # Not async. The run's server lives in `:persistent_term`, one term for the
  # virtual machine, and this module erases it for its own duration.
  use ExUnit.Case, async: false

  alias Mediate.Dev.Cerbos

  @moduletag :cerbos

  setup do
    dir = Path.join([File.cwd!(), "tmp", "cerbos-policies-" <> Integer.to_string(System.unique_integer([:positive]))])
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{policy_dir: dir}
  end

  test "the run's server is started once and answered to every caller after", %{policy_dir: policy_dir} do
    previous = :persistent_term.get(Cerbos, nil)
    :persistent_term.erase(Cerbos)
    on_exit(fn -> if previous, do: :persistent_term.put(Cerbos, previous), else: :persistent_term.erase(Cerbos) end)

    assert_raise RuntimeError, ~r/no Cerbos server was started for this run/, fn -> Cerbos.current!() end

    current = Cerbos.start(policy_dir: policy_dir)
    assert Cerbos.start(policy_dir: policy_dir) == current
    assert Cerbos.current!() == current
    assert Cerbos.healthy?(current.http)

    assert :ok = Cerbos.stop(current)
    assert :ok = Cerbos.stop_all(:ok)
    refute File.dir?(current.dir)
    refute Cerbos.healthy?(current.http)
  end
end
