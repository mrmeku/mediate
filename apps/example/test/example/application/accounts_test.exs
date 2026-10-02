defmodule Example.Application.AccountsTest do
  use Example.FakeCase, async: true

  alias Example.Application.Accounts
  alias Example.Domain.Account
  alias Example.Domain.Membership
  alias Example.Domain.TeamRole
  alias Example.Infrastructure.Repo

  test "memberships and team roles are granted and revoked as rows", %{world: world} do
    assert %Membership{role: :maintainer} = Accounts.add_membership("frank", world.project.id, :maintainer)
    assert Accounts.remove_membership("frank", world.project.id) == 1
    assert Accounts.remove_membership("frank", world.project.id) == 0
    assert %TeamRole{role: :reviewer} = Accounts.add_team_role("frank", world.team.id, :reviewer)
  end

  test "the override permission is a row, and privileged accounts are invited with their roles", %{} do
    refute Accounts.override_permitted?("frank")
    assert Accounts.override_permitted?("gil")
    assert [{%Account{id: "gil", person_id: "gil"}, [:override]}] = Accounts.privileged()
  end

  test "employment and country are corrected in place", %{} do
    assert %Account{employment: :contractor} = Accounts.set_employment("ann", :contractor)
    assert %Account{country: "FR"} = Accounts.set_country("ann", "FR")
    assert %Account{employment: :contractor, country: "FR"} = Repo.get(Account, "ann")
  end
end
