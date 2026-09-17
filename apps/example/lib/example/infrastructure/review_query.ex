defmodule Example.Infrastructure.ReviewQuery do
  # Hidden, because the queries a context runs are not its surface. What is
  # here is the population `Example.Application.Review` ranges over. It is
  # every enterprise, every account as the subject it stands for, and the
  # repositories the teams of an enterprise own. The reviewer reads all three
  # under a declared exemption, so the rows are the whole of what there is
  # to review. The proposals over those repositories are the population of
  # `approve_visibility`.
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias Ecto.Query
  alias Example.Domain.Enterprise
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.User

  @doc "Every enterprise, in id order."
  @spec enterprises() :: Query.t()
  def enterprises, do: from(a in Enterprise, order_by: a.id)

  @doc "Every account as its id and its kind, in id order, which the caller reads as a subject."
  @spec subjects() :: Query.t()
  def subjects, do: from(u in User, order_by: u.id, select: {u.id, u.kind})

  @doc "The ids of the repositories the teams of an enterprise own, in id order."
  @spec repositories(integer()) :: Query.t()
  def repositories(enterprise_id) when is_integer(enterprise_id) do
    from(d in Repository,
      join: o in assoc(d, :owning_team),
      where: o.enterprise_id == ^enterprise_id,
      order_by: d.id,
      select: d.id
    )
  end

  @doc "The ids of the proposals over the repositories the teams of an enterprise own, in id order."
  @spec proposals(integer()) :: Query.t()
  def proposals(enterprise_id) when is_integer(enterprise_id) do
    from(p in Proposal,
      join: d in assoc(p, :repository),
      join: o in assoc(d, :owning_team),
      where: o.enterprise_id == ^enterprise_id,
      order_by: p.id,
      select: p.id
    )
  end
end
