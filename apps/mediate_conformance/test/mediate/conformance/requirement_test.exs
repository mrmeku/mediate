defmodule Mediate.Conformance.RequirementTest do
  use ExUnit.Case, async: true

  alias Mediate.Conformance.Requirement

  test "the ids of a table are the ids of its rows, in order" do
    assert Requirement.ids(:engine) == Enum.map(Requirement.all(:engine), & &1.id)
    assert Requirement.ids(:repo) == Enum.map(Requirement.all(:repo), & &1.id)
  end

  test "no id appears twice across the two tables" do
    ids = Requirement.ids(:engine) ++ Requirement.ids(:repo)
    assert Enum.uniq(ids) == ids
  end

  test "fetch! answers a row of either table and raises for an id neither holds" do
    assert %Requirement{id: "ac3-01", controls: ["AC-3"]} = Requirement.fetch!("ac3-01")
    assert %Requirement{id: "repo-02", controls: ["AU-12"]} = Requirement.fetch!("repo-02")
    assert_raise ArgumentError, ~r/no requirement xx-99/, fn -> Requirement.fetch!("xx-99") end
  end

  test "a test name is the id and the text" do
    assert Requirement.test_name("au2-02") == "au2-02 " <> Requirement.fetch!("au2-02").text
  end
end
