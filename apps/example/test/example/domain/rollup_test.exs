defmodule Example.Domain.RollupTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Example.Domain.Restrictions
  alias Example.Domain.Rollup

  @countries ~w(AU CA FR GB US)

  property "a repository's rollup admits no subject a directory of it denies" do
    check all(visibilities <- visibilities()) do
      rollup = Rollup.of(visibilities)

      for visibility <- visibilities, do: assert(Rollup.covers?(rollup, visibility))
    end
  end

  property "labels and restrictions are the union of the directories'" do
    check all(visibilities <- visibilities()) do
      rollup = Rollup.of(visibilities)

      for field <- [:labels, :restrictions] do
        values = Enum.flat_map(visibilities, & &1[field])

        assert rollup[field] == Enum.sort(Enum.uniq(values))
      end
    end
  end

  property "a country one directory withholds is released by no rollup" do
    check all(visibilities <- visibilities()) do
      releasing = Enum.filter(visibilities, &(:releasable_to in &1.restrictions))
      released = Enum.filter(@countries, fn country -> Enum.all?(releasing, &(country in &1.releasable_to)) end)

      assert Rollup.of(visibilities).releasable_to == if(releasing == [], do: [], else: released)
    end
  end

  property "the directories' order is not the rollup's, and a directory counted twice changes nothing" do
    check all(visibilities <- visibilities(), extra <- visibility()) do
      assert Rollup.of(Enum.reverse(visibilities)) == Rollup.of(visibilities)
      assert Rollup.of([extra | visibilities] ++ [extra]) == Rollup.of([extra | visibilities])
    end
  end

  property "a directory added to a repository never widens its rollup" do
    check all(visibilities <- visibilities(), extra <- visibility()) do
      assert Rollup.covers?(Rollup.of([extra | visibilities]), Rollup.of(visibilities))
    end
  end

  property "a visibility covers itself, and a rollup over a rollup covers what the inner one covers" do
    check all([one, two, three] <- list_of(visibility(), length: 3)) do
      middle = Rollup.of([one, two])
      wide = Rollup.of([middle, three])

      assert Rollup.covers?(one, one)
      assert Rollup.covers?(wide, one)
    end
  end

  property "a visibility is its fields, sorted and without repeats, and reading it again changes nothing" do
    check all(row <- row()) do
      visibility = Rollup.visibility(row)

      assert Enum.sort(Map.keys(visibility)) == Enum.sort(Restrictions.fields())
      assert Rollup.visibility(visibility) == visibility

      for field <- Restrictions.fields() do
        values = visibility[field]
        assert values == Enum.sort(Enum.uniq(values))
      end
    end
  end

  defp visibilities, do: list_of(visibility(), max_length: 4)

  defp visibility, do: map(row(), &Rollup.visibility/1)

  defp row do
    fixed_map(%{
      labels: list_of(member_of(~w(crypto secrets docs)), max_length: 3),
      restrictions: list_of(member_of(Restrictions.all()), max_length: 3),
      releasable_to: list_of(member_of(@countries), max_length: 3)
    })
  end

  test "a visibility is the three fields, sorted and without repeats" do
    row = %{
      labels: ["crypto", "secrets", "crypto"],
      restrictions: [:export_controlled, :employees_only],
      releasable_to: ["GB", "FR"],
      other: 1
    }

    assert Rollup.visibility(row) == %{
             labels: ["crypto", "secrets"],
             restrictions: [:employees_only, :export_controlled],
             releasable_to: ["FR", "GB"]
           }

    assert Rollup.visibility(%{}) == %{labels: [], restrictions: [], releasable_to: []}
  end

  test "the rollup over rows carries their labels and restrictions and the countries all of them release to" do
    wide = %{restrictions: [:releasable_to], releasable_to: ["FR", "GB", "US"], labels: ["crypto"]}
    narrow = %{restrictions: [:releasable_to, :export_controlled], releasable_to: ["GB", "US"]}

    assert Rollup.of([wide, narrow]) == %{
             labels: ["crypto"],
             restrictions: [:export_controlled, :releasable_to],
             releasable_to: ["GB", "US"]
           }

    assert Rollup.of([]) == %{labels: [], restrictions: [], releasable_to: []}
  end

  test "a rollup covers a visibility when it carries every label and restriction the visibility does" do
    rollup = %{restrictions: [:export_controlled, :employees_only], labels: ["crypto"]}

    assert Rollup.covers?(rollup, %{restrictions: [:export_controlled]})
    refute Rollup.covers?(%{restrictions: [:export_controlled]}, rollup)
  end

  test "a rollup covers a visibility with REGIONS when it releases to no country outside the visibility's list" do
    visibility = %{restrictions: [:releasable_to], releasable_to: ["US"]}

    assert Rollup.covers?(%{restrictions: [:releasable_to], releasable_to: ["US"]}, visibility)
    refute Rollup.covers?(%{restrictions: [:releasable_to], releasable_to: ["FR", "US"]}, visibility)
  end
end
