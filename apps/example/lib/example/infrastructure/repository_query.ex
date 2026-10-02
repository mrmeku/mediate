defmodule Example.Infrastructure.RepositoryQuery do
  @moduledoc false
  # Hidden, because the queries an application module runs are not its
  # surface. What is here is which rows `Example.Application.Repositories`
  # asks for: the repositories a rule admits, the directories of a
  # repository, and the override reports of a team. A rule is the `dynamic`
  # `Mediate.filter/4` answered with. The query carries it and does not
  # read it, so nothing here decides who can see a row.

  import Ecto.Query, only: [from: 2, where: 2]

  alias Ecto.Query
  alias Example.Domain.Directory
  alias Example.Domain.OverrideReport
  alias Example.Domain.Repository

  @doc "The repositories a rule admits, in id order, each with its rollup."
  @spec filtered(Query.dynamic_expr()) :: Query.t()
  def filtered(rule), do: from(r in Repository, where: ^rule, order_by: r.id, preload: :visibility)

  @doc "Every directory of a repository, which the rollup comes from."
  @spec directories(integer()) :: Query.t()
  def directories(repository_id) when is_integer(repository_id), do: where(Directory, repository_id: ^repository_id)

  @doc "The directories of a repository a rule admits, in id order."
  @spec directories(integer(), Query.dynamic_expr()) :: Query.t()
  def directories(repository_id, rule) when is_integer(repository_id) do
    from(d in Directory, where: d.repository_id == ^repository_id, where: ^rule, order_by: d.id)
  end

  @doc "The override reports of a team, oldest first."
  @spec override_reports(integer()) :: Query.t()
  def override_reports(team_id) when is_integer(team_id) do
    from(r in OverrideReport, where: r.team_id == ^team_id, order_by: r.id)
  end
end
