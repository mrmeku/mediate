defmodule Mediate.OpenFGA.Conformance.Population do
  @moduledoc """
  A population of the reference world's tables for the cases: three
  accounts, two of them cleared, three folders, and four memberships
  across them. `write/1` and `clear/1` go through the mediated repo a row
  at a time, so every change is one the handler sees.

  A folder with no membership on it and an account with no clearance are
  both in here on purpose. An object that requires no tuple is what the
  cases hold the mapping to as much as one that does. The change is one
  membership taken away. It leaves the folder it sat on in the tables for
  a sync to put right.
  """

  @behaviour Mediate.OpenFGA.Population

  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Membership
  alias Mediate.OpenFGA.Population

  @accounts [{"acct-a", "cleared"}, {"acct-b", "cleared"}, {"acct-c", nil}]
  @exemption {:exempt, "openfga population"}
  @folders [1, 2, 3]
  @memberships [{"acct-a", 1, :editor}, {"acct-b", 1, :reader}, {"acct-a", 2, :reader}, {"acct-c", 2, :editor}]

  @impl Population
  def write(repo) do
    Enum.each(@accounts, fn {id, clearance} -> insert(repo, %Account{id: id, clearance: clearance}) end)
    Enum.each(@folders, fn id -> insert(repo, %Folder{id: id, name: "folder #{id}"}) end)

    Enum.each(@memberships, fn {account, folder, role} ->
      insert(repo, %Membership{account_id: account, folder_id: folder, role: role})
    end)
  end

  @impl Population
  def clear(repo) do
    Enum.each(repo.all(Membership, authorized_by: @exemption), &repo.delete!(&1, authorized_by: @exemption))
    Enum.each(repo.all(Account, authorized_by: @exemption), &repo.delete!(&1, authorized_by: @exemption))
    Enum.each(repo.all(Folder, authorized_by: @exemption), &repo.delete!(&1, authorized_by: @exemption))
  end

  @impl Population
  def change(repo) do
    membership = repo.get_by!(Membership, [account_id: "acct-b", folder_id: 1], authorized_by: @exemption)
    _deleted = repo.delete!(membership, authorized_by: @exemption)

    :ok
  end

  @impl Population
  def absent("clearance"), do: "clearance:nothing-is-classified-this-way"
  def absent(type), do: "#{type}:999999"

  defp insert(repo, row) do
    _inserted = repo.insert!(row, authorized_by: @exemption)

    :ok
  end
end
