defmodule Example.Scenarios.Table do
  @moduledoc """
  The scenario table of `docs/example.md` under "The scenarios" as data. The freeze test holds
  this module to the document row for row. The `scenario` macro validates
  every declaration against it, and the count test reads its size. A row
  changes in the document and here in one commit.

  `clauses` names the clauses, `:c1` to `:c13`, or `:review` for the
  scenario that shows `Mediate.review/5`.
  """

  alias Example.Scenarios.Row

  @rows [
    {"enf-01", "An Account with a Membership in a Repository's Project reads it", :enforcement, ~w[AC-3], [:c1]},
    {"enf-02", "The Repository denies an Account with neither a Membership nor a TeamRole", :enforcement, ~w[AC-3],
     [:c1]},
    {"enf-03",
     "An Account with a TeamRole in the owning Team reads a Repository of that Team's Project without a Membership",
     :enforcement, ~w[AC-3], [:c1]},
    {"enf-04", "An EMPLOYEE ONLY Repository denies a contractor with a Membership in its Project", :enforcement,
     ~w[AC-3 AC-16*], [:c2]},
    {"enf-05", "An EXPORT Repository denies an Account whose country is not the owning Enterprise's", :enforcement,
     ~w[AC-3], [:c2]},
    {"enf-06", "A REGIONS Repository denies an Account whose country is outside its list", :enforcement, ~w[AC-3], [:c2]},
    {"enf-07", "An INVITE ONLY Repository admits an Account on its invited list and denies an Account not on it",
     :enforcement, ~w[AC-3], [:c2, :c6]},
    {"enf-08", "A Repository with two restrictions denies an Account who passes only one of them", :enforcement, ~w[AC-3],
     [:c2]},
    {"enf-09", "A sensitive Label's implied restriction denies an Account that the declared restrictions allow",
     :enforcement, ~w[AC-3], [:c3]},
    {"enf-10", "Any Account with an access path reads a Repository with no restrictions", :enforcement, ~w[AC-3], [:c2]},
    {"enf-11",
     "An Account outside the Enterprise's country gets a checkout that omits an EXPORT Directory and returns the rest of the Repository",
     :enforcement, ~w[AC-3], [:c4, :c13]},
    {"enf-12", "The domain refuses at write time a Repository visibility that drops a Directory's restriction",
     :enforcement, ~w[AC-3 AC-16*], [:c4]},
    {"enf-13", "After the embargo lifts a contractor with a Membership reads an EMPLOYEE ONLY Repository", :enforcement,
     ~w[AC-3], [:c5]},
    {"enf-14", "Before the embargo lifts, by Mediate's clock, the same Repository denies the contractor", :enforcement,
     ~w[AC-3], [:c5]},
    {"enf-15", "A Repository whose embargo lifted still denies an Account with no access path", :enforcement, ~w[AC-3],
     [:c5, :c1]},
    {"enf-16", "A place on the invited list without a Membership does not grant the read", :enforcement, ~w[AC-3], [:c6]},
    {"enf-17", "`filter` does not admit a Repository of another Enterprise, and `authorize` denies it", :enforcement,
     ~w[AC-3], [:c1, :c13]},
    {"enf-18", "The whole Repository denies an Account that one Directory releases to and another does not", :enforcement,
     ~w[AC-3 AC-16*], [:c4, :c2]},
    {"lp-01", "A Project member without a TeamRole cannot change a Repository's visibility", :least_privilege,
     ~w[AC-6 AC-6(1)], [:c7]},
    {"lp-02", "An admin of another Team cannot change the visibility", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-03", "An admin of the owning Team changes the visibility", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-04", "Only an admin sets an embargo date or lifts an embargo", :least_privilege, ~w[AC-6(1)], [:c7]},
    {"lp-05", "A Directory's visibility change needs an admin of the Repository's owning Team", :least_privilege,
     ~w[AC-6(1)], [:c7, :c4]},
    {"lp-06", "An ordinary account cannot invoke the override", :least_privilege, ~w[AC-6(10)], [:c10]},
    {"lp-07", "A privileged account is a separate account, and the same person's ordinary account cannot override",
     :least_privilege, ~w[AC-6(2)], [:c10]},
    {"lp-08", "The access review lists every privileged account and the permissions it holds", :least_privilege,
     ~w[AC-6(5) AC-2(7)], [:c7, :c10]},
    {"sod-01", "A different reviewer approves the visibility change an admin proposes", :separation_of_duties, ~w[AC-5],
     [:c9]},
    {"sod-02", "The proposer, who is also a reviewer, cannot approve their own proposal", :separation_of_duties, ~w[AC-5],
     [:c9]},
    {"sod-03", "A proposal without approval does not change the visibility", :separation_of_duties, ~w[AC-5 CM-5], [:c9]},
    {"rev-01",
     "A revoked Membership denies the next decision, and the test records the latency and its components and never asserts them",
     :revocation_and_expiry, ~w[AC-2 PS-4 AC-3(8)*], [:c11, :c12]},
    {"rev-02", "Removal from an INVITE ONLY list denies the next read", :revocation_and_expiry, ~w[AC-2 AC-2(1)], [:c11]},
    {"rev-03", "A change of employment from employee to contractor denies an EMPLOYEE ONLY read at the next decision",
     :revocation_and_expiry, ~w[AC-2 PS-5], [:c11]},
    {"rev-04", "A corrected country applies at the next decision", :revocation_and_expiry, ~w[AC-2 AC-16*], [:c11]},
    {"rev-05", "An archived Project revokes every Membership's access path at the next decision", :revocation_and_expiry,
     ~w[AC-2 AC-2(3)], [:c11]},
    {"rev-06",
     "A revocation deletes only the grant, the Repository and the Project remain, and the add and the remove each emit an identity write event",
     :revocation_and_expiry, ~w[AC-2(4)], [:c11]},
    {"rvw-01", "The access review lists who can read what today, per Enterprise", :access_review, ~w[AC-2 AC-6(7)],
     [:review]},
    {"ia-01", "An admin whose session re-authenticated within the window changes a visibility", :re_authentication,
     ~w[IA-11], [:c8]},
    {"ia-02", "An admin whose session is older than the window cannot change a visibility until re-authentication",
     :re_authentication, ~w[IA-11], [:c8]},
    {"ia-03", "Mediate refuses a visibility change whose context carries no `reauthenticated_at` fact",
     :re_authentication, ~w[IA-11], [:c8]},
    {"ovr-01",
     "A privileged Account with the override permission reads outside C1 with a justification, and the read emits the override event and leaves an override report for the owning Team",
     :audited_override, ~w[AC-6(9) AU-6], [:c10]},
    {"ovr-02", "The override refuses a call without a justification", :audited_override, ~w[AC-6(9)], [:c10]},
    {"ovr-03", "The override never reaches C7, and a privileged Account cannot change a visibility through it",
     :audited_override, ~w[AC-6(9) AC-6(1)], [:c10, :c7]}
  ]

  @scenarios Enum.map(@rows, fn {id, sentence, group, controls, clauses} ->
               %Row{id: id, sentence: sentence, group: group, controls: controls, clauses: clauses}
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

  @doc "How many scenarios a deployment runs: the rows."
  @spec count() :: non_neg_integer()
  def count, do: length(@scenarios)
end
