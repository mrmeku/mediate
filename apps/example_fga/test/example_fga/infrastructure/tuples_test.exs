defmodule ExampleFga.Infrastructure.TuplesTest do
  use ExUnit.Case, async: true

  alias ExampleFga.Infrastructure.Tuples

  test "a repository with no visibility states nothing about labels, releases, or restrictions" do
    assert Tuples.visibility(nil, "repository:1", nil) == []
  end
end
