defmodule Mediate.Postgres.Conformance.Rules do
  @moduledoc """
  The fixture's rule as policies. `Mediate.Conformance.World` has the rule.

  The read policy of a folder is a live membership on it, held by the kind
  that asks, on a cleared account. The edit policy adds the editor role.
  An item answers as its folder does. The kind and the moment are the
  session settings the adapter binds before each statement. A setting the
  seam has cleared reads as the empty string, which is why the moment goes
  through `NULLIF` before its cast.

  Folders carry the update gate as well, and items carry none, so a run
  covers both the gated path and the ungated one. The migration admits
  inserts and deletes on the two protected tables, because forced
  row-level security refuses every statement no policy admits. The fixture
  writes its population through the same role it reads with.

  The owner role reads the protected tables while no operation is in force,
  which is the exemption the seam leaves behind for it. Forced row-level
  security applies the policies to the table's owner too. Without that
  policy the role that owns the tables reads none of their rows.

  The migration number is the policy version every decision over the
  fixture names. The migration grants the application role `SELECT` on the
  migrations table, so the role reads that number back.
  """

  use Ecto.Migration

  alias Mediate.Postgres.Migration

  @version 20_260_915_000_001
  @role "mediate_app"
  @owner "mediate_owner"
  @folders "mediate_fixture_folders"
  @items "mediate_fixture_items"

  @cleared """
  EXISTS (SELECT 1 FROM mediate_fixture_accounts a
          WHERE a.id = current_setting('mediate.subject_id', true) AND a.clearance = 'cleared')
  """

  @holding """
  m.account_id = current_setting('mediate.subject_id', true)
            AND m.subject_kind = current_setting('mediate.subject_kind', true)
            AND (m.expires_at IS NULL
                 OR m.expires_at > NULLIF(current_setting('mediate.now', true), '')::timestamptz)
  """

  @folder_member """
  EXISTS (SELECT 1 FROM mediate_fixture_memberships m
          WHERE m.folder_id = mediate_fixture_folders.id
            AND #{@holding})
  """

  @folder_editor """
  EXISTS (SELECT 1 FROM mediate_fixture_memberships m
          WHERE m.folder_id = mediate_fixture_folders.id
            AND #{@holding}
            AND m.role = 'editor')
  """

  @item_member """
  EXISTS (SELECT 1 FROM mediate_fixture_memberships m
          WHERE m.folder_id = mediate_fixture_items.folder_id
            AND #{@holding})
  """

  @item_editor """
  EXISTS (SELECT 1 FROM mediate_fixture_memberships m
          WHERE m.folder_id = mediate_fixture_items.folder_id
            AND #{@holding}
            AND m.role = 'editor')
  """

  @doc "The migration number, which is the policy version a decision over the fixture names."
  @spec version() :: pos_integer()
  def version, do: @version

  @doc "The tables the policies protect."
  @spec tables() :: [String.t()]
  def tables, do: [@folders, @items]

  @doc "Protect the fixture's object tables, write the policies of its two operations, and publish the version."
  @spec up() :: :ok
  def up do
    repo = repo()
    rules(repo, @folders, @folder_member, @folder_editor)
    rules(repo, @items, @item_member, @item_editor)

    :ok =
      Migration.gate!(repo, table: @folders, operation: :edit, using: @folder_editor, with_check: @folder_editor)

    :ok = Migration.grant!(repo, table: "schema_migrations", to: @role, commands: [:select])
    _version = Migration.publish!(repo, published())
    :ok
  end

  @doc """
  The read policy over folders: a live membership on the folder, held by
  the kind that asks, on a cleared account. When the caller names a role, the
  membership must be of that role. The boot policy names no role. The
  change-management artifact names `reader`, which is the tighten.
  """
  @spec folder_read(String.t() | nil) :: String.t()
  def folder_read(role) when is_binary(role) or is_nil(role) do
    by_role = if role, do: "\n            AND m.role = '#{role}'", else: ""

    """
    EXISTS (SELECT 1 FROM mediate_fixture_memberships m
            WHERE m.folder_id = mediate_fixture_folders.id
              AND #{@holding}#{by_role}) AND #{@cleared}
    """
  end

  defp rules(repo, table, member, editor) do
    :ok = Migration.protect!(repo, table)
    :ok = Migration.policy!(repo, table: table, operation: :read, using: "#{member} AND #{@cleared}")
    :ok = Migration.policy!(repo, table: table, operation: :edit, using: "#{editor} AND #{@cleared}")
    :ok = Migration.admit!(repo, table: table, command: :insert)
    :ok = Migration.admit!(repo, table: table, command: :delete)
    Migration.exempt!(repo, table: table, to: @owner, commands: [:select])
  end

  defp published do
    [
      tables: tables(),
      version: @version,
      author: "mediate_postgres",
      approval: "the conformance suite"
    ]
  end
end
