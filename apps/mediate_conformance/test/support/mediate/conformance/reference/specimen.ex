defmodule Mediate.Conformance.Reference.Specimen do
  @moduledoc """
  What `Mediate.Conformance.RepoCase` writes when this package holds the
  core's sandboxed repo to the five repo requirements. The identity row is
  a membership, whose role is a fact field, under a declared exemption. An
  UPDATE by hand is the write that goes around the mediated repo. The
  protected row is a folder, read under a decision the fake engine
  allows.
  """

  @behaviour Mediate.Conformance.Specimen

  alias Ecto.Changeset
  alias Mediate.Conformance.Specimen
  alias Mediate.Dev.Sandbox
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Membership
  alias Mediate.Test.Fake
  alias Mediate.TestRepos.Sandboxed

  @exemption {:exempt, "the conformance reference specimen"}

  @impl Specimen
  def setup(tags) when is_map(tags) do
    :ok = Sandbox.setup(Sandboxed, tags)
    Mediate.Test.with_config(engine: {Fake, effect: :allow})
  end

  @impl Specimen
  def identity_row, do: %Membership{account_id: "conformance", role: :reader}

  @impl Specimen
  def fact_changeset(%Membership{} = membership), do: Changeset.change(membership, role: :editor)

  @impl Specimen
  def authorized_by, do: @exemption

  @impl Specimen
  def write_around(%Membership{id: id}) do
    sql = "UPDATE mediate_fixture_memberships SET role = 'editor' WHERE id = $1"
    _result = Sandboxed.query!(sql, [id], authorized_by: @exemption)
    :ok
  end

  @impl Specimen
  def protected_row, do: %Folder{name: "conformance"}

  @impl Specimen
  def read_decision(%Folder{id: id}) do
    {:ok, decision} = Mediate.authorize({:user, "conformance"}, :read, {:folder, id})
    decision
  end
end
