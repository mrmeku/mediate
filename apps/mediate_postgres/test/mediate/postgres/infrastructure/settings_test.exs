defmodule Mediate.Postgres.SettingsTest do
  use ExUnit.Case, async: true

  alias Mediate.Postgres.Infrastructure.Settings

  @at ~U[2026-09-08 12:00:00Z]

  test "four settings are always set, and every supplied fact is set under its own name" do
    settings = Settings.of(subject(), :read, environment(%{nationality: "us", reauthenticated_at: @at}))

    assert settings.pairs == [
             {"mediate.subject_id", "acct-a"},
             {"mediate.subject_kind", "user"},
             {"mediate.operation", "read"},
             {"mediate.now", "2026-09-08T12:00:00Z"},
             {"mediate.nationality", "us"},
             {"mediate.reauthenticated_at", "2026-09-08T12:00:00Z"}
           ]
  end

  test "a fact the caller did not supply is the empty string, and a list joins with commas" do
    settings = Settings.of(subject(), :read, environment(%{override: nil, categories: ["prvcy", "fouo"], level: 3}))
    values = Map.new(settings.pairs)

    assert values["mediate.override"] == ""
    assert values["mediate.categories"] == "prvcy,fouo"
    assert values["mediate.level"] == "3"
  end

  test "a fact of a shape the settings have no rendering for is set as the term inspected" do
    settings = Settings.of(subject(), :read, environment(%{window: {@at, @at}}))

    assert Map.new(settings.pairs)["mediate.window"] == inspect({@at, @at})
  end

  test "a decision's time alone gives the same settings with no supplied fact" do
    assert Settings.of(subject(), :read, @at) == Settings.of(subject(), :read, environment(%{}))
  end

  test "the statement is one SELECT over set_config with a parameter pair per setting" do
    {statement, params} = Settings.statement(Settings.of(subject(), :edit, environment(%{})))

    assert statement ==
             "SELECT set_config($1, $2, true), set_config($3, $4, true), " <>
               "set_config($5, $6, true), set_config($7, $8, true)"

    assert params == [
             "mediate.subject_id",
             "acct-a",
             "mediate.subject_kind",
             "user",
             "mediate.operation",
             "edit",
             "mediate.now",
             "2026-09-08T12:00:00Z"
           ]
  end

  test "the hash covers every name and value, so a changed fact changes it" do
    read = Settings.of(subject(), :read, environment(%{}))
    edit = Settings.of(subject(), :edit, environment(%{}))

    assert Settings.hash(read) == Settings.hash(Settings.of(subject(), :read, environment(%{})))
    assert Settings.hash(read) != Settings.hash(edit)
    assert Settings.hash(read) =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "what a call puts back holds the outer call's values and empties the names only it set" do
    outer = Settings.of(subject(), :read, environment(%{}))
    inner = Settings.of({:user, "acct-b"}, :edit, environment(%{nationality: "fr"}))

    assert Settings.restored(inner, outer).pairs == [
             {"mediate.nationality", ""},
             {"mediate.subject_id", "acct-a"},
             {"mediate.subject_kind", "user"},
             {"mediate.operation", "read"},
             {"mediate.now", "2026-09-08T12:00:00Z"}
           ]
  end

  defp subject, do: {:user, "acct-a"}

  defp environment(facts), do: Map.put(facts, :now, @at)
end
