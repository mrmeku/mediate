defmodule Mediate.Fixture.Tables do
  @moduledoc """
  Creates the fixture tables and the application role's grants, through an
  owner-role repo. A membership is unique per account and folder, so a
  second grant of the same pair is a write the database refuses.
  """

  use Boundary, top_level?: true, deps: []

  @names ~w(mediate_fixture_folders mediate_fixture_items mediate_fixture_memberships)

  @tables [
    "CREATE TABLE mediate_fixture_folders (id bigserial PRIMARY KEY, name text)",
    "CREATE TABLE mediate_fixture_items (id bigserial PRIMARY KEY, title text, " <>
      "folder_id bigint REFERENCES mediate_fixture_folders(id))",
    "CREATE TABLE mediate_fixture_memberships (id bigserial PRIMARY KEY, account_id text, role text, " <>
      "subject_kind text NOT NULL DEFAULT 'user', expires_at timestamptz, " <>
      "folder_id bigint REFERENCES mediate_fixture_folders(id), UNIQUE (account_id, folder_id))",
    "CREATE TABLE mediate_fixture_accounts (id text PRIMARY KEY, clearance text)"
  ]

  @doc "Creates the tables. The repo is an owner-role repo whose calls carry the library exemption."
  @spec create!(module()) :: :ok
  def create!(repo) when is_atom(repo) do
    Enum.each(@tables, &repo.query!/1)

    Enum.each(@names, fn name ->
      repo.query!("GRANT SELECT, INSERT, UPDATE, DELETE ON #{name} TO mediate_app")
      repo.query!("GRANT USAGE, SELECT ON SEQUENCE #{name}_id_seq TO mediate_app")
    end)

    repo.query!("GRANT SELECT, INSERT, UPDATE, DELETE ON mediate_fixture_accounts TO mediate_app")
    :ok
  end
end
