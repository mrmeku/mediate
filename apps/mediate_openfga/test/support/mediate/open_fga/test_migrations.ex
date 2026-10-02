defmodule Mediate.OpenFGA.TestMigrations do
  @moduledoc "The migrations this package's own test run applies. A deployment has its own set."

  use Boundary, top_level?: true, deps: [Ecto.Migration, Mediate.OpenFGA.Migration, Mediate.Relay.Migration]
end

defmodule Mediate.OpenFGA.TestMigrations.Outbox do
  @moduledoc "Calls the outbox migration and the cursor migration the way a deployment's migration does."
  use Ecto.Migration

  alias Mediate.OpenFGA.Migration

  @doc "Creates the outbox table, then the cursor table."
  @spec up() :: :ok
  def up do
    :ok = Migration.up()
    Mediate.Relay.Migration.up()
  end

  @doc "Drops the cursor table, then the outbox table."
  @spec down() :: :ok
  def down do
    :ok = Mediate.Relay.Migration.down()
    Migration.down()
  end
end
