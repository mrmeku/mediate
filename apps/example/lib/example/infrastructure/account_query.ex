defmodule Example.Infrastructure.AccountQuery do
  @moduledoc false
  # Hidden, because the queries an application module runs are not its
  # surface. What is here is which rows `Example.Application.Accounts` asks
  # for. They are an account's membership in a project, the override
  # permission it holds, and every privileged account with its permissions.

  import Ecto.Query, only: [from: 2]

  alias Ecto.Query
  alias Example.Domain.Account
  alias Example.Domain.Membership
  alias Example.Domain.Permission

  @doc "An account's membership in a project, which a revocation deletes a row at a time."
  @spec membership(String.t(), integer()) :: Query.t()
  def membership(account_id, project_id) when is_binary(account_id) and is_integer(project_id) do
    from(a in Membership, where: a.account_id == ^account_id and a.project_id == ^project_id)
  end

  @doc "The override permission an account holds, if it holds one."
  @spec override_permission(String.t()) :: Query.t()
  def override_permission(account_id) when is_binary(account_id) do
    from(p in Permission, where: p.account_id == ^account_id and p.permission == :override)
  end

  @doc "Every privileged account with each permission it holds beside it, and one row where it holds none."
  @spec privileged() :: Query.t()
  def privileged do
    from(a in Account,
      where: a.kind == :privileged,
      left_join: p in Permission,
      on: p.account_id == a.id,
      order_by: [a.id, p.permission],
      select: {a, p.permission}
    )
  end
end
