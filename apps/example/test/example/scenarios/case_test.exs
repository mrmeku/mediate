defmodule Example.Scenarios.CaseTest do
  use Example.Scenarios.Case, async: true

  alias Example.Scenarios.Case

  scenario "enf-01", "A User with a Membership in a Repository's Project reads it", rule: :c1 do
    assert true
  end

  scenario "enf-09", "A sensitive Label's implied restriction denies " <> "a User that the declared restrictions allow",
    rule: :c3 do
    assert true
  end

  scenario "rev-06",
           "A revocation deletes only the fact, the Repository and the Project remain, " <>
             "and the grant and the revoke each emit a change event",
           rule: :c11 do
    assert true
  end

  test "the macro names the test by id and sentence, and tags it from the table" do
    assert Case.__tags__("enf-01", "A User with a Membership in a Repository's Project reads it", rule: :c1) ==
             [scenario: "enf-01", rule: :c1, controls: ["AC-3"]]

    assert Case.__name__("enf-01", "sentence") == "enf-01 sentence"
  end

  test "a scenario that tests more than one rule takes either of them" do
    sentence =
      "A User outside the Enterprise's country gets a checkout that omits an EXPORT Directory and " <>
        "returns the rest of the Repository"

    assert Case.__tags__("enf-11", sentence, rule: :c13) == [scenario: "enf-11", rule: :c13, controls: ["AC-3"]]
  end

  test "a declaration that drifts from the table is refused" do
    sentence = "A User with a Membership in a Repository's Project reads it"

    assert_raise ArgumentError, ~r/no scenario "enf-99"/, fn ->
      Case.__tags__("enf-99", sentence, rule: :c1)
    end

    assert_raise ArgumentError, ~r/reads/, fn ->
      Case.__tags__("enf-01", "another sentence", rule: :c1)
    end

    assert_raise ArgumentError, ~r/tests \[:c1\]/, fn ->
      Case.__tags__("enf-01", sentence, rule: :c2)
    end
  end
end
