defmodule Mediate.Rbac.Conformance.Predicates do
  @moduledoc """
  The predicates of the conformance role table: attribute checks as
  `dynamic` expressions over the row. The clearance is a fact of the
  account. The kind and the expiry are facts of the membership the grant
  reads, because a membership is unique per account and folder. The
  membership on the row's folder must belong to the subject's kind. It must
  not have expired at the moment the port stamped on the request.
  """

  import Ecto.Query, only: [dynamic: 2, from: 2]

  alias Mediate.Conformance.Fixture.World
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Membership

  @doc "The subject's account carries the clearance the fixture's rule asks for."
  @spec cleared(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def cleared({_kind, id}, %{now: _now}) do
    cleared = World.cleared()
    dynamic([_row], exists(from(a in Account, where: a.id == ^id and a.clearance == ^cleared)))
  end

  @doc "The subject's membership on the folder row belongs to its kind and is live."
  @spec held(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def held(subject, %{now: _now} = environment) do
    dynamic([row], row.id in subquery(live(subject, environment)))
  end

  @doc "The item row's folder has a membership for the subject that belongs to its kind and is live."
  @spec folder_held(Mediate.subject(), Mediate.environment()) :: Ecto.Query.dynamic_expr()
  def folder_held(subject, %{now: _now} = environment) do
    dynamic([row], row.folder_id in subquery(live(subject, environment)))
  end

  defp live({kind, id}, %{now: now}) do
    from(m in Membership,
      where: m.account_id == ^id and m.subject_kind == ^kind,
      where: is_nil(m.expires_at) or m.expires_at > ^now,
      select: m.folder_id
    )
  end
end
