defmodule Mix.Tasks.Mediate.SurfaceTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Mediate.Surface

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  test "with no argument it prints the current project's surface" do
    Surface.run([])
    assert_received {:mix_shell, :info, ["module Mediate.Dev.Surface"]}
    assert_received {:mix_shell, :info, ["function Mediate.Dev.Surface.of/2 :: of(atom(), keyword()) :: t()"]}
  end

  test "with an application name it prints that application's surface" do
    Surface.run(["mediate_dev"])
    assert_received {:mix_shell, :info, ["module Mix.Tasks.Mediate.Surface"]}
  end

  test "it takes one application name or none" do
    assert_raise Mix.Error, ~r/one application name or none/, fn -> Surface.run(["a", "b"]) end
  end
end
