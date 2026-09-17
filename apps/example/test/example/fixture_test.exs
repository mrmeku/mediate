defmodule Example.FixtureTest do
  use Example.FakeCase, async: true

  alias Example.Fixture

  test "the world has its accounts, its two tenants, and its labels", %{world: world} do
    assert world.enterprise.country == "US" and world.other_enterprise.country == "FR"
    assert length(Fixture.subjects()) == 10
    assert Fixture.subject("gil") == {:privileged, "gil"}
    assert %Example.Domain.User{kind: :user, employment: :contractor} = Fixture.account!("zed", employment: :contractor)
    assert Fixture.account_ids() == ~w[ann bob carl dana eve frank gil gil-user hana ivan]
  end

  test "a repository's rollup carries its directories' restrictions", %{world: world} do
    repository =
      Fixture.repository!(world,
        restrictions: [:employees_only],
        directories: [%{name: "d", contents: "d", restrictions: [:export_controlled]}]
      )

    assert Enum.sort(repository.visibility.restrictions) == [:employees_only, :export_controlled]
    assert %Example.Domain.Visibility{invited: ["ann"]} = Fixture.set_invited!(repository, ["ann"])
    assert %Example.Domain.Project{archived_at: %DateTime{}} = Fixture.archive_project!(world.project)
  end

  test "a repository's rollup releases to no country a directory withholds", %{world: world} do
    repository =
      Fixture.repository!(world,
        restrictions: [:releasable_to],
        releasable_to: ["FR", "US"],
        directories: [%{name: "d", contents: "d", restrictions: [:releasable_to], releasable_to: ["US"]}]
      )

    assert repository.visibility.releasable_to == ["US"]
  end
end
