defmodule Example.Application.Accounts do
  @moduledoc """
  Accounts and the roles they hold: assignments to programs, roles in
  offices, and the override permission. Role administration is not itself a
  rule of the example, so its writes carry a declared exemption that names
  it. A rule reads a role inside the adapter at check time. A revocation
  deletes nothing but the role row.

  A grant to many accounts at once is a row at a time in one transaction.
  The seam refuses a plain `insert_all` on an audited schema, because one
  statement cannot say what change each row made.
  """

  alias Example.Domain.AccountRole
  alias Example.Domain.Assignment
  alias Example.Domain.OfficeRole
  alias Example.Domain.User
  alias Example.Infrastructure.AccountQuery
  alias Example.Infrastructure.Repo

  @administration {:exempt, "role administration: no rule of the example governs who grants roles"}

  @doc "Assign an account to a program with a role."
  @spec assign(String.t(), integer(), :lead | :member) :: Assignment.t()
  def assign(user_id, program_id, role) when is_binary(user_id) and role in [:lead, :member] do
    Repo.insert!(%Assignment{user_id: user_id, program_id: program_id, role: role}, mediate: @administration)
  end

  @doc """
  Revoke an account's assignment to a program, one row at a time, so each
  revocation is a change event of its own. Returns the count of rows
  removed.
  """
  @spec unassign(String.t(), integer()) :: non_neg_integer()
  def unassign(user_id, program_id) when is_binary(user_id) do
    user_id
    |> AccountQuery.assignment(program_id)
    |> Repo.all(mediate: @administration)
    |> Enum.map(&Repo.delete!(&1, mediate: @administration))
    |> length()
  end

  @doc "Give an account a role in an office."
  @spec office_role(String.t(), integer(), :designator | :approver) :: OfficeRole.t()
  def office_role(user_id, office_id, role) when is_binary(user_id) and role in [:designator, :approver] do
    Repo.insert!(%OfficeRole{user_id: user_id, office_id: office_id, role: role}, mediate: @administration)
  end

  @doc "Grant the override permission to an account."
  @spec grant_override(String.t()) :: AccountRole.t()
  def grant_override(user_id) when is_binary(user_id) do
    Repo.insert!(%AccountRole{user_id: user_id, role: :override}, mediate: @administration)
  end

  @doc "Whether the account holds the override permission."
  @spec override_permitted?(String.t()) :: boolean()
  def override_permitted?(user_id) when is_binary(user_id) do
    Repo.exists?(AccountQuery.override_role(user_id))
  end

  @doc "Change an account's employment. The next check sees it."
  @spec set_employment(String.t(), :federal | :contractor) :: User.t()
  def set_employment(user_id, employment) when is_binary(user_id) and employment in [:federal, :contractor] do
    user = Repo.get!(User, user_id)
    Repo.update!(Ecto.Changeset.change(user, employment: employment), mediate: @administration)
  end

  @doc "Correct an account's nationality. The next check sees it."
  @spec set_nationality(String.t(), String.t()) :: User.t()
  def set_nationality(user_id, nationality) when is_binary(user_id) and is_binary(nationality) do
    user = Repo.get!(User, user_id)
    Repo.update!(Ecto.Changeset.change(user, nationality: nationality), mediate: @administration)
  end

  @doc "Every privileged account with the roles it holds, by account id."
  @spec privileged() :: [{User.t(), [atom()]}]
  def privileged do
    query = AccountQuery.privileged()

    query
    |> Repo.all()
    |> Enum.group_by(fn {user, _role} -> user end, fn {_user, role} -> role end)
    |> Enum.map(fn {user, roles} -> {user, Enum.reject(roles, &is_nil/1)} end)
    |> Enum.sort_by(fn {user, _roles} -> user.id end)
  end
end
