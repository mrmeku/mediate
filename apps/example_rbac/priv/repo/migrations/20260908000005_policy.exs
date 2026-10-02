defmodule ExampleRbac.Migrations.Policy do
  @moduledoc false
  use Ecto.Migration

  # The policy of this deployment is `ExampleRbac.Infrastructure.Policy`, a
  # module the engine evaluates in the application, so the database holds
  # nothing for it: no policy, no role beyond the two the domain migration
  # makes, no column. The migration is here so that the set of migrations
  # reads the same across the deployments, and so that the structure file is
  # the example's tables and nothing else, which makes the diff a check that
  # the policy is in code rather than a gap in the record.
  def up, do: :ok
  def down, do: :ok
end
