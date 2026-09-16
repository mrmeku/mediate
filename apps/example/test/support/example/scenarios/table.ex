defmodule Example.Scenarios.Table do
  @moduledoc """
  The scenario table of `docs/example.md` under "The scenarios" as data. The freeze test holds
  this module to the document row for row. The `scenario` macro validates
  every declaration against it, and the count test reads its size. A row
  changes in the document and here in one commit.

  `tests` names the rules, `:c1` to `:c13`, or `:review` for the scenario
  that shows the port's review verb.
  """

  alias Example.Scenarios.Row

  @rows [
    {"enf-01", "A User with an Assignment to a Document's Program reads it", :enforcement, ~w[AC-3], [:c1]},
    {"enf-02", "The Document denies a User with neither " <> "an Assignment nor an OfficeRole", :enforcement, ~w[AC-3],
     [:c1]},
    {"enf-03",
     "A User with an OfficeRole in the designating Office reads a Document of that Office's Program " <>
       "without an Assignment", :enforcement, ~w[AC-3], [:c1]},
    {"enf-04", "A FED ONLY Document denies a contractor " <> "with an Assignment to its Program", :enforcement,
     ~w[AC-3 AC-16*], [:c2]},
    {"enf-05", "A NOFORN Document of a domestic Agency denies a foreign national", :enforcement, ~w[AC-3], [:c2]},
    {"enf-06", "A REL TO Document denies a User whose nationality is outside its list", :enforcement, ~w[AC-3], [:c2]},
    {"enf-07", "A DL ONLY Document admits a User on its list and denies a User not on it", :enforcement, ~w[AC-3],
     [:c2, :c6]},
    {"enf-08", "A Document with two controls denies a User who passes only one of them", :enforcement, ~w[AC-3], [:c2]},
    {"enf-09", "A Specified category's implied control denies a User that the declared controls allow", :enforcement,
     ~w[AC-3], [:c3]},
    {"enf-10", "Any User with a lawful purpose reads a Document with no controls", :enforcement, ~w[AC-3], [:c2]},
    {"enf-11", "A foreign national's redacted read omits a NOFORN Portion and returns the rest of the Document",
     :enforcement, ~w[AC-3], [:c4, :c13]},
    {"enf-12", "The domain refuses at write time a Document marking that drops a Portion's control", :enforcement,
     ~w[AC-3 AC-16*], [:c4]},
    {"enf-13", "After the decontrol date a contractor with an Assignment reads a FED ONLY Document", :enforcement,
     ~w[AC-3], [:c5]},
    {"enf-14", "Before the decontrol date, by the port's clock, the same Document denies the contractor", :enforcement,
     ~w[AC-3], [:c5]},
    {"enf-15", "A decontrolled Document still denies " <> "a User with no lawful purpose", :enforcement, ~w[AC-3],
     [:c5, :c1]},
    {"enf-16", "DL ONLY membership without an Assignment does not grant the read", :enforcement, ~w[AC-3], [:c6]},
    {"enf-17", "`scope` does not return a Document of another Agency, and `check` does not allow it", :enforcement,
     ~w[AC-3], [:c1, :c13]},
    {"enf-18", "The whole Document denies a User that one Portion releases to and another does not", :enforcement,
     ~w[AC-3 AC-16*], [:c4, :c2]},
    {"lp-01", "A Program member without an OfficeRole cannot change a Document's marking", :least_privilege,
     ~w[AC-6 AC-6(1)], [:c7]},
    {"lp-02", "A designator of another Office cannot change the marking", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-03", "A designator of the designating Office changes the marking", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-04", "Only a designator sets a decontrol date or decontrols a Document", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-05", "A Portion's marking change needs a designator of the Document's designating Office", :least_privilege,
     ~w[AC-6(1)], [:c7, :c4]},
    {"lp-06", "An ordinary account cannot invoke the override", :least_privilege, ~w[AC-6(10)], [:c10]},
    {"lp-07",
     "A privileged account is a separate account, and the same person's ordinary account cannot " <>
       "override", :least_privilege, ~w[AC-6(2)], [:c10]},
    {"lp-08", "The access review lists every privileged account and every permission a role holds", :least_privilege,
     ~w[AC-6(5) AC-2(7)], [:c7, :c10]},
    {"sod-01", "A different approver approves " <> "the marking change a designator proposes", :separation_of_duties,
     ~w[AC-5], [:c9]},
    {"sod-02", "The proposer, who is also an approver, cannot approve their own proposal", :separation_of_duties,
     ~w[AC-5], [:c9]},
    {"sod-03", "A proposal without approval does not change the marking", :separation_of_duties, ~w[AC-5 CM-5], [:c9]},
    {"rev-01",
     "A revoked Assignment denies the next check, and the test records the latency and its components " <>
       "and never asserts them", :revocation_and_expiry, ~w[AC-2 PS-4 AC-3(8)*], [:c11, :c12]},
    {"rev-02", "Removal from a DL ONLY list denies the next read", :revocation_and_expiry, ~w[AC-2 AC-2(1)], [:c11]},
    {"rev-03", "A change of employment from federal to contractor denies a FED ONLY read at the next check",
     :revocation_and_expiry, ~w[AC-2 PS-5], [:c11]},
    {"rev-04", "A corrected nationality applies at the next check", :revocation_and_expiry, ~w[AC-2 AC-16*], [:c11]},
    {"rev-05", "A closed Program revokes every Assignment's lawful purpose at the next check", :revocation_and_expiry,
     ~w[AC-2 AC-2(3)], [:c11]},
    {"rev-06",
     "A revocation deletes only the fact, the Document and the Program remain, and the grant and the " <>
       "revoke each emit a change event", :revocation_and_expiry, ~w[AC-2(4)], [:c11]},
    {"rvw-01", "The access review lists who can read what today, per Agency", :access_review, ~w[AC-2 AC-6(7)],
     [:review]},
    {"ia-01", "A designator whose session re-authenticated within the window changes a marking", :re_authentication,
     ~w[IA-11], [:c8]},
    {"ia-02",
     "A designator whose session is older than the window cannot change a marking until " <>
       "re-authentication", :re_authentication, ~w[IA-11], [:c8]},
    {"ia-03", "The port refuses a marking change that has no re-authentication fact", :re_authentication, ~w[IA-11],
     [:c8]},
    {"ovr-01",
     "A privileged user with the override permission reads outside C1 with a justification, and the " <>
       "read emits an event and reports to the designating Office", :emergency_override, ~w[AC-6(9) AU-6], [:c10]},
    {"ovr-02", "The override refuses a call without a justification", :emergency_override, ~w[AC-6(9)], [:c10]},
    {"ovr-03", "The override never reaches C7, and a privileged user cannot change a marking through it",
     :emergency_override, ~w[AC-6(9) AC-6(1)], [:c10, :c7]}
  ]

  @scenarios Enum.map(@rows, fn {id, sentence, group, controls, tests} ->
               %Row{id: id, sentence: sentence, group: group, controls: controls, tests: tests}
             end)

  @doc "Every scenario, in the table's order."
  @spec all() :: [Row.t()]
  def all, do: @scenarios

  @doc "The ids, in the table's order."
  @spec ids() :: [String.t()]
  def ids, do: Enum.map(@scenarios, & &1.id)

  @doc "The scenario with an id."
  @spec fetch(String.t()) :: {:ok, Row.t()} | :error
  def fetch(id) when is_binary(id) do
    case Enum.find(@scenarios, &(&1.id == id)) do
      nil -> :error
      %Row{} = scenario -> {:ok, scenario}
    end
  end

  @doc "How many scenarios a thin application runs: the rows."
  @spec count() :: non_neg_integer()
  def count, do: length(@scenarios)
end
