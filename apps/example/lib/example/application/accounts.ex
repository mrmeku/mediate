defmodule Example.Application.Accounts do
  @moduledoc """
  Accounts and the grants they hold: memberships in projects, roles in
  teams, and the override permission. Membership administration is not
  itself a clause of the example, so its writes carry a declared exemption
  that names it. A clause reads a grant inside the engine at decision
  time. A revocation deletes nothing but the grant row.

  A grant to many accounts at once is a row at a time in one transaction.
  The mediated repo refuses a plain `insert_all` on an identity schema,
  because one statement cannot say what change each row made.
  """

  alias Example.Domain.Account
  alias Example.Domain.Membership
  alias Example.Domain.Permission
  alias Example.Domain.TeamRole
  alias Example.Infrastructure.AccountQuery
  alias Example.Infrastructure.Repo

  @administration {:exempt, "membership administration: no clause of the example governs who adds grants"}

  @doc "Add an account's membership in a project, with a role."
  @spec add_membership(String.t(), integer(), :maintainer | :contributor) :: Membership.t()
  def add_membership(account_id, project_id, role) when is_binary(account_id) and role in [:maintainer, :contributor] do
    Repo.insert!(%Membership{account_id: account_id, project_id: project_id, role: role}, authorized_by: @administration)
  end

  @doc """
  Remove an account's membership in a project, one row at a time, so each
  removal is an identity write event of its own. Returns the count of rows
  removed.
  """
  @spec remove_membership(String.t(), integer()) :: non_neg_integer()
  def remove_membership(account_id, project_id) when is_binary(account_id) do
    account_id
    |> AccountQuery.membership(project_id)
    |> Repo.all(authorized_by: @administration)
    |> Enum.map(&Repo.delete!(&1, authorized_by: @administration))
    |> length()
  end

  @doc "Add an account's role in a team."
  @spec add_team_role(String.t(), integer(), :admin | :reviewer) :: TeamRole.t()
  def add_team_role(account_id, team_id, role) when is_binary(account_id) and role in [:admin, :reviewer] do
    Repo.insert!(%TeamRole{account_id: account_id, team_id: team_id, role: role}, authorized_by: @administration)
  end

  @doc "Grant the override permission to an account."
  @spec grant_override(String.t()) :: Permission.t()
  def grant_override(account_id) when is_binary(account_id) do
    Repo.insert!(%Permission{account_id: account_id, permission: :override}, authorized_by: @administration)
  end

  @doc "Whether the account holds the override permission."
  @spec override_permitted?(String.t()) :: boolean()
  def override_permitted?(account_id) when is_binary(account_id) do
    Repo.exists?(AccountQuery.override_permission(account_id))
  end

  @doc "Change an account's employment. The next decision sees it."
  @spec set_employment(String.t(), :employee | :contractor) :: Account.t()
  def set_employment(account_id, employment) when is_binary(account_id) and employment in [:employee, :contractor] do
    account = Repo.get!(Account, account_id)
    Repo.update!(Ecto.Changeset.change(account, employment: employment), authorized_by: @administration)
  end

  @doc "Correct an account's country. The next decision sees it."
  @spec set_country(String.t(), String.t()) :: Account.t()
  def set_country(account_id, country) when is_binary(account_id) and is_binary(country) do
    account = Repo.get!(Account, account_id)
    Repo.update!(Ecto.Changeset.change(account, country: country), authorized_by: @administration)
  end

  @doc "Every privileged account with the permissions it holds, by account id."
  @spec privileged() :: [{Account.t(), [atom()]}]
  def privileged do
    query = AccountQuery.privileged()

    query
    |> Repo.all()
    |> Enum.group_by(fn {account, _permission} -> account end, fn {_account, permission} -> permission end)
    |> Enum.map(fn {account, permissions} -> {account, Enum.reject(permissions, &is_nil/1)} end)
    |> Enum.sort_by(fn {account, _permissions} -> account.id end)
  end
end
