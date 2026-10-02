defmodule ExampleCerbos.Migrations.Policy do
  @moduledoc false
  use Ecto.Migration

  # The policy of this deployment is the files under `priv/policies`, which
  # a Cerbos server reads, so the database holds nothing of it: no rule, no
  # role beyond the two the domain migration makes, no column. The
  # migration is here so that the set of migrations reads the same across
  # the deployments, and so that the structure file is the example's tables
  # and nothing else, which makes its diff a check that the policy lives
  # outside the database and not a gap in the record.
  def up, do: :ok
  def down, do: :ok
end
