defmodule Mediate.Dev.OpenFGASharedTest do
  # Not async. The run's server lives in `:persistent_term`, one term for the
  # virtual machine, and this module erases it for its own duration.
  use ExUnit.Case, async: false

  alias Mediate.Dev.OpenFGA

  @moduletag :fga

  test "the run's server is started once and answered to every caller after" do
    previous = :persistent_term.get(OpenFGA, nil)
    :persistent_term.erase(OpenFGA)
    on_exit(fn -> if previous, do: :persistent_term.put(OpenFGA, previous), else: :persistent_term.erase(OpenFGA) end)

    assert_raise RuntimeError, ~r/no OpenFGA server was started for this run/, fn -> OpenFGA.current!() end

    current = OpenFGA.start()
    assert OpenFGA.start() == current
    assert OpenFGA.current!() == current
    assert OpenFGA.healthy?(current.http)

    assert :ok = OpenFGA.stop(current)
    assert :ok = OpenFGA.stop_all(:ok)
    refute File.dir?(current.dir)
    refute OpenFGA.healthy?(current.http)
  end
end
