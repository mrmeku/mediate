defmodule Mediate.Postgres.Domain.SettingsTest do
  use ExUnit.Case, async: true

  alias Mediate.Postgres.Domain.Settings

  @at ~U[2026-09-08 12:00:00Z]

  test "four settings are always set, and every supplied fact is set under its own name" do
    settings = Settings.new(subject(), :read, context(%{country: "us", reauthenticated_at: @at}))

    assert settings.pairs == [
             {"mediate.subject_id", "acct-a"},
             {"mediate.subject_kind", "user"},
             {"mediate.action", "read"},
             {"mediate.now", "2026-09-08T12:00:00Z"},
             {"mediate.country", "us"},
             {"mediate.reauthenticated_at", "2026-09-08T12:00:00Z"}
           ]
  end

  test "a fact under one of the four fixed names is dropped, because the request's values win" do
    settings = Settings.new(subject(), :read, context(%{subject_id: "acct-z", action: :edit, subject_kind: :robot}))

    assert settings == Settings.new(subject(), :read, context(%{}))
  end

  test "a fact the caller did not supply is the empty string, and a list joins with commas" do
    settings = Settings.new(subject(), :read, context(%{override: nil, categories: ["prvcy", "fouo"], level: 3}))
    values = Map.new(settings.pairs)

    assert values["mediate.override"] == ""
    assert values["mediate.categories"] == "prvcy,fouo"
    assert values["mediate.level"] == "3"
  end

  test "a fact of a shape the settings have no rendering for is set as the term inspected" do
    settings = Settings.new(subject(), :read, context(%{window: {@at, @at}}))

    assert Map.new(settings.pairs)["mediate.window"] == inspect({@at, @at})
  end

  test "a decision's moment alone gives the same settings with no supplied fact" do
    assert Settings.new(subject(), :read, @at) == Settings.new(subject(), :read, context(%{}))
  end

  test "the statement is one SELECT over set_config with a parameter pair per setting" do
    {statement, params} = Settings.to_sql(Settings.new(subject(), :edit, context(%{})))

    assert statement ==
             "SELECT set_config($1, $2, true), set_config($3, $4, true), " <>
               "set_config($5, $6, true), set_config($7, $8, true)"

    assert params == [
             "mediate.subject_id",
             "acct-a",
             "mediate.subject_kind",
             "user",
             "mediate.action",
             "edit",
             "mediate.now",
             "2026-09-08T12:00:00Z"
           ]
  end

  test "the hash covers every name and value, so a changed fact changes it" do
    read = Settings.new(subject(), :read, context(%{}))
    edit = Settings.new(subject(), :edit, context(%{}))

    assert Settings.hash(read) == Settings.hash(Settings.new(subject(), :read, context(%{})))
    assert Settings.hash(read) != Settings.hash(edit)
    assert Settings.hash(read) =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "what a call puts back holds the outer call's values and empties the names only it set" do
    outer = Settings.new(subject(), :read, context(%{}))
    inner = Settings.new({:user, "acct-b"}, :edit, context(%{country: "fr"}))

    assert Settings.restored(inner, outer).pairs == [
             {"mediate.country", ""},
             {"mediate.subject_id", "acct-a"},
             {"mediate.subject_kind", "user"},
             {"mediate.action", "read"},
             {"mediate.now", "2026-09-08T12:00:00Z"}
           ]

    assert Settings.cleared(inner).pairs == Enum.map(inner.pairs, fn {name, _value} -> {name, ""} end)
  end

  defp subject, do: {:user, "acct-a"}

  defp context(facts), do: Map.put(facts, :now, @at)
end
