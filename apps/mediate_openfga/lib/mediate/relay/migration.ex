defmodule Mediate.Relay.Migration do
  @moduledoc """
  The cursor table, for a deployment's own migration to create. This
  package ships no migration files. Each deployment has one that calls
  `up/1` and `down/0`, beside the job's own tables.

  `up/1` creates `mediate_relay_cursor(name text primary key, position
  bigint not null)`, where a `Mediate.Relay` runner keeps its place. It
  grants the application role select, insert, and update. A runner
  connects as the application, and an advance of a cursor replaces the
  position of a row that is already there. The role gets no delete,
  because a migration forgets a runner when it drops the row, not the
  run time.
  """

  use Boundary, top_level?: true, deps: [Ecto.Migration]

  import Ecto.Migration

  @cursor :mediate_relay_cursor

  @schema NimbleOptions.new!(
            app_role: [
              type: :string,
              default: "mediate_app",
              doc: "The database role the application connects as. It receives the grants."
            ]
          )

  @doc "Creates the cursor table and its grants. Options: #{NimbleOptions.docs(@schema)}"
  @spec up(keyword()) :: :ok
  def up(options \\ []) when is_list(options) do
    options = NimbleOptions.validate!(options, @schema)

    create table(@cursor, primary_key: false) do
      add(:name, :text, primary_key: true)
      add(:position, :bigint, null: false)
    end

    execute("GRANT SELECT, INSERT, UPDATE ON #{@cursor} TO #{options[:app_role]}")
    :ok
  end

  @doc "Drops the cursor table."
  @spec down() :: :ok
  def down do
    drop(table(@cursor))
    :ok
  end
end
