defmodule Mediate.Postgres.RuleTest do
  use ExUnit.Case, async: true

  alias Mediate.Error
  alias Mediate.Postgres.Rule

  test "the engine's two names are told apart from a rule someone else wrote" do
    filter = rule(Rule.filter_name("read"))
    gate = rule(Rule.gate_name("change_visibility"))

    assert Rule.kind(filter) == {:filter, "read"}
    assert Rule.kind(gate) == {:gate, "change_visibility"}
    assert Rule.kind(rule("tenant_isolation")) == :other
    assert Rule.kind(rule("mediate_filter_")) == :other
  end

  test "the command letter pg_policy carries becomes the command" do
    assert Enum.map(~w[* r a w d], &Rule.command/1) == [:all, :select, :insert, :update, :delete]
  end

  test "the text a release carries names the table, the rule, and both expressions" do
    text = Rule.to_text(%{rule("mediate_filter_read") | using: "true", with_check: nil})
    assert text == "folders mediate_filter_read select\n  USING true\n  WITH CHECK -\n"
  end

  test "the text of a release reads back as the rules it carries, expressions and all" do
    rules = [
      %{
        rule("mediate_filter_read")
        | using: "(EXISTS ( SELECT 1\n   FROM public.team_roles\n  WHERE (role = 'admin'::text)))"
      },
      %{
        rule("mediate_gate_change_visibility")
        | command: :update,
          using: "true",
          with_check: "(now() > '2026-01-01'::date)"
      },
      %{rule("tenant_isolation") | command: :all}
    ]

    text = Enum.map_join(rules, &Rule.to_text/1)

    assert Rule.from_text(text) == rules
  end

  test "a release with no rules in it reads back as no rules" do
    assert Rule.from_text("") == []
    assert Rule.from_text("\n\n") == []
  end

  test "the statement that writes a rule names the command and only the clauses it has" do
    filter = %{rule("mediate_filter_read") | using: "true"}
    gate = %{rule("mediate_gate_lift_embargo") | command: :update, using: "a", with_check: "b"}

    assert Rule.to_sql(filter) == "CREATE POLICY mediate_filter_read ON folders FOR SELECT USING (true)"
    assert Rule.to_sql(gate) == "CREATE POLICY mediate_gate_lift_embargo ON folders FOR UPDATE USING (a) WITH CHECK (b)"

    assert Rule.to_sql(%{rule("p") | command: :all}) == "CREATE POLICY p ON folders FOR ALL"

    assert Rule.to_sql(%{rule("p") | command: :insert, with_check: "c"}) ==
             "CREATE POLICY p ON folders FOR INSERT WITH CHECK (c)"

    assert Rule.to_sql(%{rule("p") | command: :delete, using: "d"}) ==
             "CREATE POLICY p ON folders FOR DELETE USING (d)"
  end

  test "a name the statement cannot quote is refused rather than written" do
    assert_raise Error, ~r/invalid policy/, fn -> Rule.to_sql(%{rule(~s(a"b)) | using: "true"}) end
    assert_raise Error, ~r/invalid table/, fn -> Rule.to_sql(%{rule("p") | table: "Folders"}) end
  end

  defp rule(name) do
    %Rule{name: name, table: "folders", command: :select, using: nil, with_check: nil}
  end
end
