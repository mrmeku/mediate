defmodule ExampleOpenFGA.Infrastructure.TuplesTest do
  use ExUnit.Case, async: true

  alias ExampleOpenFGA.Infrastructure.Tuples

  test "a repository with no visibility states nothing about labels, countries, or restrictions" do
    assert Tuples.visibility(nil, "repository:1", nil) == []
  end
end
