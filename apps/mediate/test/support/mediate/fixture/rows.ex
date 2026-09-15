defmodule Mediate.Fixture.Rows do
  @moduledoc """
  What `Mediate.Conformance.RepoCase` writes when the core package holds
  its own sandboxed repo to the five guarantees. The audited row is a
  membership, whose role is a fact field, under a declared exemption. An
  UPDATE by hand is the write that goes around the seam. The protected row
  is a folder, read under a decision the fake adapter allows.
  """

  @behaviour Mediate.Conformance.RepoCase.Rows

  alias Ecto.Changeset
  alias Mediate.Conformance.RepoCase.Rows
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Membership
  alias Mediate.Test.Fake
  alias Mediate.TestRepos.Sandboxed

  @exempt {:exempt, "conformance: the rows the repo case writes"}

  @impl Rows
  def setup(tags) when is_map(tags) do
    :ok = Sandbox.setup(Sandboxed, tags)
    Mediate.Test.with_config(adapter: {Fake, verdict: :allow})
  end

  @impl Rows
  def row, do: %Membership{account_id: "conformance", role: :reader}

  @impl Rows
  def change(%Membership{} = membership), do: Changeset.change(membership, role: :editor)

  @impl Rows
  def mediation, do: @exempt

  @impl Rows
  def around(%Membership{id: id}) do
    sql = "UPDATE mediate_fixture_memberships SET role = 'editor' WHERE id = $1"
    _result = Sandboxed.query!(sql, [id], mediate: @exempt)
    :ok
  end

  @impl Rows
  def protected, do: %Folder{name: "conformance"}

  @impl Rows
  def decision(%Folder{id: id}) do
    {:ok, decision} = Mediate.authorize({:user, "conformance"}, :read, {:folder, id})
    decision
  end
end
