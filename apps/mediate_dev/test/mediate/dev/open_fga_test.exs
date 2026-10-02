defmodule Mediate.Dev.OpenFGATest do
  use ExUnit.Case, async: true

  alias Mediate.Dev.OpenFGA

  @moduletag :fga

  test "a server of the test's own answers its health endpoint" do
    server = OpenFGA.start_supervised!()

    assert OpenFGA.healthy?(server.http)
    assert server.http != server.grpc
    assert File.dir?(server.dir)
  end

  test "a server of the test's own takes the directory the caller names" do
    dir = Path.join([File.cwd!(), "tmp", "openfga-named-" <> Integer.to_string(System.unique_integer([:positive]))])
    on_exit(fn -> File.rm_rf!(dir) end)

    server = OpenFGA.start_supervised!(dir: dir)

    assert server.dir == dir
    assert OpenFGA.healthy?(server.http)
  end

  test "the options say what a caller may pass" do
    assert %NimbleOptions{} = OpenFGA.options_schema()
    assert OpenFGA.options_schema().schema[:timeout][:default] == 20_000

    assert_raise NimbleOptions.ValidationError, fn -> OpenFGA.start_supervised!(datastore: "memory") end
  end

  test "an address nothing listens on is not healthy" do
    refute OpenFGA.healthy?("127.0.0.1:1")
  end
end
