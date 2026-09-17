defmodule Mediate.CredoTest do
  use ExUnit.Case, async: true

  # A check module compiles under `Code.ensure_loaded?(Credo.Check)`, so the
  # package holds a check only when Credo is on the code path at the moment
  # this package compiles. An installed package compiles in production,
  # where a requirement held to `[:dev, :test]` is absent and Mix orders
  # nothing. The package then compiles to no module at all, Credo prints
  # `Ignoring an undefined check`, and the run passes with both checks gone.
  # An optional requirement holds in every environment and orders Credo
  # first, and it still leaves the adopter to declare Credo.
  test "the requirement on credo is optional and holds in every environment" do
    {:credo, _requirement, options} = List.keyfind(Mix.Project.config()[:deps], :credo, 0)

    assert Keyword.get(options, :optional) == true
    assert Keyword.get(options, :only) == nil
  end
end
