defmodule Example.Scenarios.CaseTest do
  use Example.Scenarios.Case, async: true

  alias Example.Scenarios.Case

  scenario "enf-01", "An Account with a Membership in a Repository's Project reads it", clause: :c1 do
    assert true
  end

  scenario "enf-09",
           "A sensitive Label's implied restriction denies " <> "an Account that the declared restrictions allow",
           clause: :c3 do
    assert true
  end

  scenario "rev-06",
           "A revocation deletes only the grant, the Repository and the Project remain, " <>
             "and the add and the remove each emit an identity write event",
           clause: :c11 do
    assert true
  end

  test "the macro names the test by id and sentence, and tags it from the table" do
    assert Case.__tags__("enf-01", "An Account with a Membership in a Repository's Project reads it", clause: :c1) ==
             [scenario: "enf-01", clause: :c1, controls: ["AC-3"]]

    assert Case.__name__("enf-01", "sentence") == "enf-01 sentence"
  end

  test "a scenario that proves more than one clause takes either of them" do
    sentence =
      "An Account outside the Enterprise's country gets a checkout that omits an EXPORT Directory and " <>
        "returns the rest of the Repository"

    assert Case.__tags__("enf-11", sentence, clause: :c13) == [scenario: "enf-11", clause: :c13, controls: ["AC-3"]]
  end

  test "a declaration that drifts from the table is refused" do
    sentence = "An Account with a Membership in a Repository's Project reads it"

    assert_raise ArgumentError, ~r/no scenario "enf-99"/, fn ->
      Case.__tags__("enf-99", sentence, clause: :c1)
    end

    assert_raise ArgumentError, ~r/reads/, fn ->
      Case.__tags__("enf-01", "another sentence", clause: :c1)
    end

    assert_raise ArgumentError, ~r/proves \[:c1\]/, fn ->
      Case.__tags__("enf-01", sentence, clause: :c2)
    end
  end
end
