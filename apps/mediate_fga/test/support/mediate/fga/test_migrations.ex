defmodule Mediate.Fga.TestMigrations do
  @moduledoc "The migrations this package's own test run applies. A thin application has its own set."

  use Boundary, top_level?: true, deps: [Ecto.Migration, Mediate.Fga.Migration]
end

defmodule Mediate.Fga.TestMigrations.Outbox do
  @moduledoc "Calls the outbox helper and the cursor helper the way a thin application's migration does."
  use Ecto.Migration

  alias Mediate.Fga.Migration

  @doc "Creates the outbox table, then the cursor table."
  @spec up() :: :ok
  def up do
    :ok = Migration.outbox_up()
    Migration.cursor_up()
  end

  @doc "Drops the cursor table, then the outbox table."
  @spec down() :: :ok
  def down do
    :ok = Migration.cursor_down()
    Migration.outbox_down()
  end
end
