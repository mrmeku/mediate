defmodule Mediate.Rbac.Conformance.Predicates do
  @moduledoc """
  The predicates of the conformance policy: fact checks as `dynamic`
  expressions over the row. The clearance is a fact of the account. The
  kind and the expiry are facts of the membership the grant rule reads,
  because a membership is unique per account and folder. The membership on
  the row's folder must belong to the subject's kind. It must not have
  expired at the moment the core stamped on the request.
  """

  import Ecto.Query, only: [dynamic: 2, from: 2]

  alias Mediate.Conformance.Reference.World
  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Membership

  @doc "The subject's account holds the clearance the world's rule asks for."
  @spec cleared(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def cleared({_kind, id}, %{now: _now}) do
    cleared = World.cleared()
    dynamic([_row], exists(from(a in Account, where: a.id == ^id and a.clearance == ^cleared)))
  end

  @doc "The subject's membership on the folder row belongs to its kind and is live."
  @spec held(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def held(subject, %{now: _now} = context) do
    dynamic([row], row.id in subquery(live(subject, context)))
  end

  @doc "The item row's folder has a membership for the subject that belongs to its kind and is live."
  @spec folder_held(Mediate.subject(), Mediate.context()) :: Ecto.Query.dynamic_expr()
  def folder_held(subject, %{now: _now} = context) do
    dynamic([row], row.folder_id in subquery(live(subject, context)))
  end

  defp live({kind, id}, %{now: now}) do
    from(m in Membership,
      where: m.account_id == ^id and m.subject_kind == ^kind,
      where: is_nil(m.expires_at) or m.expires_at > ^now,
      select: m.folder_id
    )
  end
end
