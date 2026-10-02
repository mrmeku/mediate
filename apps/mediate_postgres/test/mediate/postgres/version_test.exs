defmodule Mediate.Postgres.VersionTest do
  use ExUnit.Case, async: true

  alias Mediate.PolicyRelease
  alias Mediate.Postgres.Rule
  alias Mediate.Postgres.Version

  @rules [
    %Rule{name: "mediate_filter_read", table: "folders", command: :select, using: "true", with_check: nil},
    %Rule{name: "mediate_gate_edit", table: "folders", command: :update, using: "false", with_check: "false"},
    %Rule{name: "mediate_filter_read", table: "items", command: :select, using: "true", with_check: nil}
  ]

  test "the release names the migration number and carries the rules as text" do
    released_at = DateTime.utc_now()
    release = release(released_at: released_at)

    assert %PolicyRelease{engine: Mediate.Postgres, policy_version: "20260101000001"} = release
    assert {release.author, release.approval} == {"mediate_postgres", "the conformance suite"}
    assert release.released_at == released_at
    assert release.text == Version.text(@rules)
    assert release.text_hash == Version.text_hash(@rules)
    assert release.text_hash =~ ~r/\A[0-9a-f]{64}\z/
    assert release.text_location == nil
  end

  test "over the text cap the release names the tables as its location and hashes the text all the same" do
    release = release(policy_text_bytes: 8)

    assert release.text == nil
    assert release.text_location == "policies on folders, items"
    assert release.text_hash == release().text_hash
  end

  test "the text reads back through the rule, so the release carries what the database holds" do
    assert Rule.from_text(Version.text(@rules)) == @rules
  end

  defp release(overrides \\ []) do
    options = [
      policy_version: 20_260_101_000_001,
      author: "mediate_postgres",
      approval: "the conformance suite",
      released_at: DateTime.utc_now(),
      policy_text_bytes: 65_536
    ]

    Version.release(Mediate.Postgres, @rules, Keyword.merge(options, overrides))
  end
end
