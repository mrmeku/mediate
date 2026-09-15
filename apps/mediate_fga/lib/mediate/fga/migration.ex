defmodule Mediate.Fga.Migration do
  @moduledoc """
  The outbox table and the cursor table, for a thin application's own
  migration to create. This package ships no migration files. Each thin
  application has one that calls these.

  ```elixir
  defmodule ExampleFga.Repo.Migrations.Fga do
    use Ecto.Migration

    def up do
      :ok = Mediate.Fga.Migration.outbox_up()
      Mediate.Fga.Migration.cursor_up()
    end

    def down do
      :ok = Mediate.Fga.Migration.cursor_down()
      Mediate.Fga.Migration.outbox_down()
    end
  end
  ```

  `outbox_up/1` creates `mediate_fga_outbox(id bigserial primary key,
  object text not null)` and grants the application role select, insert,
  and delete. The handler writes the marker in the transaction that
  changed the rows. The drain reads a batch and deletes what it delivered.
  Both run as the application. The role gets no update, because a marker
  never changes after its write.

  `cursor_up/1` creates `mediate_relay_cursor(name text primary key,
  position bigint not null)`, where a `Mediate.Fga.Relay` runner keeps its
  place. It grants the application role select, insert, and update. A
  runner connects as the application, and an advance of a cursor replaces
  the position of a row that is already there. The role gets no delete,
  because a migration forgets a runner when it drops the row, not the run
  time.
  """

  use Boundary, top_level?: true, deps: [Ecto.Migration]

  import Ecto.Migration

  @outbox :mediate_fga_outbox
  @cursor :mediate_relay_cursor

  @schema NimbleOptions.new!(
            app_role: [
              type: :string,
              default: "mediate_app",
              doc: "The database role the application connects as. It receives the grants."
            ]
          )

  @doc "Creates the outbox table and its grants. Options: #{NimbleOptions.docs(@schema)}"
  @spec outbox_up(keyword()) :: :ok
  def outbox_up(options \\ []) when is_list(options) do
    options = NimbleOptions.validate!(options, @schema)

    create table(@outbox, primary_key: false) do
      add(:id, :bigserial, primary_key: true)
      add(:object, :text, null: false)
    end

    execute("GRANT SELECT, INSERT, DELETE ON #{@outbox} TO #{options[:app_role]}")
    execute("GRANT USAGE ON SEQUENCE #{@outbox}_id_seq TO #{options[:app_role]}")
    :ok
  end

  @doc "Drops the outbox table."
  @spec outbox_down() :: :ok
  def outbox_down do
    drop(table(@outbox))
    :ok
  end

  @doc "Creates the cursor table and its grants. Options: #{NimbleOptions.docs(@schema)}"
  @spec cursor_up(keyword()) :: :ok
  def cursor_up(options \\ []) when is_list(options) do
    options = NimbleOptions.validate!(options, @schema)

    create table(@cursor, primary_key: false) do
      add(:name, :text, primary_key: true)
      add(:position, :bigint, null: false)
    end

    execute("GRANT SELECT, INSERT, UPDATE ON #{@cursor} TO #{options[:app_role]}")
    :ok
  end

  @doc "Drops the cursor table."
  @spec cursor_down() :: :ok
  def cursor_down do
    drop(table(@cursor))
    :ok
  end
end
