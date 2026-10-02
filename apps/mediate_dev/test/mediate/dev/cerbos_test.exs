defmodule Mediate.Dev.CerbosTest do
  use ExUnit.Case, async: true

  alias Mediate.Dev.Cerbos

  @moduletag :cerbos

  setup do
    dir = Path.join([File.cwd!(), "tmp", "cerbos-policies-" <> Integer.to_string(System.unique_integer([:positive]))])
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{policy_dir: dir}
  end

  test "a server of the test's own answers its health endpoint", %{policy_dir: policy_dir} do
    server = Cerbos.start_supervised!(policy_dir: policy_dir)

    assert Cerbos.healthy?(server.http)
    assert server.policy_dir == policy_dir
    assert File.dir?(server.dir)
    assert File.read!(server.config_file) =~ ~s(httpListenAddr: "#{server.http}")
    assert File.read!(server.config_file) =~ "watchForChanges: true"
  end

  test "the options say what a caller may pass" do
    assert %NimbleOptions{} = Cerbos.options_schema()
    assert Cerbos.options_schema().schema[:policy_dir][:required]

    assert_raise NimbleOptions.ValidationError, fn -> Cerbos.start_supervised!(watch: false) end
  end

  test "an address nothing listens on is not healthy" do
    refute Cerbos.healthy?("127.0.0.1:1")
  end
end
