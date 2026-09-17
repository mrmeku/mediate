defmodule Example.Scenarios.Review do
  @moduledoc "The access-review scenario, rvw-01."

  use Boundary,
    top_level?: true,
    deps: [Example, Example.Fixture, Example.Scenarios.Support, ExUnit]

  import Example.Scenarios.Support
  import ExUnit.Assertions

  alias Example.Application.Review
  alias Example.Fixture

  @spec rvw_01() :: term()
  def rvw_01 do
    world = Fixture.world!()
    open = Fixture.repository!(world)
    employees = Fixture.repository!(world, restrictions: [:employees_only])
    globex = Fixture.repository!(world, project: world.other_project, team: world.other_team)

    settle()
    report = Review.report(subject("eve"), fresh())
    [_head, acme, other_section] = String.split(report, ~r/^enterprise /m)
    assert_section(acme, "Acme", ann: [open, employees], bob: [open], frank: [], ivan: [])
    assert_section(other_section, "Globex", ivan: [globex], ann: [])
    readers = Review.readers(subject("eve"), world.enterprise, fresh())
    assert readers[subject("ann")] == [open.id, employees.id]
    assert readers[subject("bob")] == [open.id]
  end

  defp assert_section(section, enterprise, reads) do
    assert section =~ enterprise

    for {account, repositories} <- reads do
      assert section =~ "#{account} reads [#{Enum.map_join(repositories, ", ", & &1.id)}]"
    end
  end
end
