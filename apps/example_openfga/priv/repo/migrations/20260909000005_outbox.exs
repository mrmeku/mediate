defmodule ExampleOpenFGA.Migrations.Outbox do
  @moduledoc false
  use Ecto.Migration

  alias Mediate.OpenFGA.Migration

  # The policy of this deployment is the model under `priv/policies`, which
  # the server holds and names by id, so the database holds no policy of its
  # own. What it does hold is the delivery: one marker per object a write may
  # have moved the store behind on, and the cursor saying how far the runner
  # has got.
  def up do
    :ok = Migration.up(app_role: "mediate_app")
    :ok = Mediate.Relay.Migration.up(app_role: "mediate_app")
  end

  def down do
    :ok = Mediate.Relay.Migration.down()
    :ok = Migration.down()
  end
end
