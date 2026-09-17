defmodule Example.Infrastructure.AccountQuery do
  @moduledoc false
  # Hidden, because the queries a context runs are not its surface. What is
  # here is which rows `Example.Application.Accounts` asks for. They are an
  # account's membership in a project, the override permission it holds, and
  # every privileged account with its roles.

  import Ecto.Query, only: [from: 2]

  alias Ecto.Query
  alias Example.Domain.AccountRole
  alias Example.Domain.Membership
  alias Example.Domain.User

  @doc "An account's membership in a project, which a revocation deletes a row at a time."
  @spec membership(String.t(), integer()) :: Query.t()
  def membership(user_id, project_id) when is_binary(user_id) and is_integer(project_id) do
    from(a in Membership, where: a.user_id == ^user_id and a.project_id == ^project_id)
  end

  @doc "The override permission an account holds, if it holds one."
  @spec override_role(String.t()) :: Query.t()
  def override_role(user_id) when is_binary(user_id) do
    from(r in AccountRole, where: r.user_id == ^user_id and r.role == :override)
  end

  @doc "Every privileged account with each role it holds beside it, and one row where it holds none."
  @spec privileged() :: Query.t()
  def privileged do
    from(u in User,
      where: u.kind == :privileged,
      left_join: r in AccountRole,
      on: r.user_id == u.id,
      order_by: [u.id, r.role],
      select: {u, r.role}
    )
  end
end
