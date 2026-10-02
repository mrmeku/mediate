defmodule Mediate.Postgres.Conformance.Reference do
  @moduledoc """
  The reference world's rule as policies, in a migration.
  `Mediate.Conformance.Reference.World` has the rule.

  The read rule of a folder is a live membership on it, held by the kind
  that asks, on a cleared account. The edit rule adds the editor role. An
  item answers as its folder does. The kind and the moment are the
  session settings the engine sets before each statement. A setting the
  mediated repo has cleared reads as the empty string, which is why the
  moment goes through `NULLIF` before its cast.

  Folders carry the gate rule as well, and items carry none, so a run
  covers both the gated path and the ungated one. The migration admits
  inserts and deletes on the two protected tables, because forced
  row-level security refuses every statement no rule admits. The world
  writes its population through the same role it reads with.

  The owner role reads the protected tables while no action is in force,
  which is the exemption the mediated repo leaves behind for it. Forced
  row-level security applies the rules to the table's owner too. Without
  that rule the role that owns the tables reads none of their rows.

  The migration number is the policy version every decision over the
  world names. The migration grants the application role `SELECT` on the
  migration source, so the role reads that number back.
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

  @doc "The migration number, which is the policy version a decision over the world names."
  @spec version() :: pos_integer()
  def version, do: @version

  @doc "The tables the rules protect."
  @spec tables() :: [String.t()]
  def tables, do: [@folders, @items]

  @doc "Protects the world's resource tables, writes the rules of its two actions, and releases the version."
  @spec up() :: :ok
  def up do
    repo = repo()
    rules(repo, @folders, @folder_member, @folder_editor)
    rules(repo, @items, @item_member, @item_editor)
    :ok = Migration.gate!(repo, table: @folders, action: :edit, using: @folder_editor, with_check: @folder_editor)
    :ok = Migration.privileges!(repo, table: "schema_migrations", to: @role, commands: [:select])
    _release = Migration.release!(repo, released())
    :ok
  end

  @doc """
  The `USING` of the folder read rule: a live membership on the folder,
  held by the kind that asks, on a cleared account. When the caller names
  a role, the membership must be of that role. The boot rule names no
  role. The policy artifact names `reader`, which is the tighten.
  """
  @spec folder_read_using(String.t() | nil) :: String.t()
  def folder_read_using(role) when is_binary(role) or is_nil(role) do
    by_role = if role, do: "\n            AND m.role = '#{role}'", else: ""

    """
    EXISTS (SELECT 1 FROM mediate_fixture_memberships m
            WHERE m.folder_id = mediate_fixture_folders.id
              AND #{@holding}#{by_role}) AND #{@cleared}
    """
  end

  defp rules(repo, table, member, editor) do
    :ok = Migration.protect!(repo, table)
    :ok = Migration.filter!(repo, table: table, action: :read, using: "#{member} AND #{@cleared}")
    :ok = Migration.filter!(repo, table: table, action: :edit, using: "#{editor} AND #{@cleared}")
    :ok = Migration.admit!(repo, table: table, command: :insert)
    :ok = Migration.admit!(repo, table: table, command: :delete)
    Migration.exempt!(repo, table: table, to: @owner, commands: [:select])
  end

  defp released do
    [
      tables: tables(),
      policy_version: @version,
      author: "mediate_postgres",
      approval: "the conformance suite"
    ]
  end
end
