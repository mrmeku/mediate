defmodule Mediate.OpenFGA.Migration do
  @moduledoc """
  The outbox table, for a deployment's own migration to create. This
  package ships no migration files. Each deployment has one that calls
  this module and `Mediate.Relay.Migration`:

  ```elixir
  defmodule MyApp.Repo.Migrations.OpenFGA do
    use Ecto.Migration

    def up do
      :ok = Mediate.OpenFGA.Migration.up()
      Mediate.Relay.Migration.up()
    end

    def down do
      :ok = Mediate.Relay.Migration.down()
      Mediate.OpenFGA.Migration.down()
    end
  end
  ```

  `up/1` creates `mediate_openfga_outbox(id bigserial primary key, object
  text not null)` and grants the application role select, insert, and
  delete. The handler writes the marker in the transaction that changed
  the rows. A pass reads a batch and deletes what it delivered. Both run
  as the application. The role gets no update, because a marker never
  changes after its write.
  """

  use Boundary, top_level?: true, deps: [Ecto.Migration]

  import Ecto.Migration

  @outbox :mediate_openfga_outbox

  @schema NimbleOptions.new!(
            app_role: [
              type: :string,
              default: "mediate_app",
              doc: "The database role the application connects as. It receives the grants."
            ]
          )

  @doc "Creates the outbox table and its grants. Options: #{NimbleOptions.docs(@schema)}"
  @spec up(keyword()) :: :ok
  def up(options \\ []) when is_list(options) do
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
  @spec down() :: :ok
  def down do
    drop(table(@outbox))
    :ok
  end
end
