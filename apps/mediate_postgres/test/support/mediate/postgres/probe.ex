defmodule Mediate.Postgres.Probe do
  @moduledoc """
  Tables of its own for the cases the fixture cannot carry. One table has a
  policy that reads a column no declaration names, and a policy that reads
  a table no bound schema names. One has the shape of a migrations table
  and holds no version. Either policy on a fixture table widens what the
  fixture's own scenarios read. So the probe keeps its own tables, and the
  fixture's stay as the conformance migration wrote them.
  """

  use Boundary, top_level?: true, deps: [Ecto, Mediate, Mediate.Postgres], exports: [Row]

  alias Mediate.Postgres.Migration

  @table "mediate_probe_rows"
  @versions "mediate_probe_versions"
  @undeclared "current_setting('mediate.probe', true) = label"
  @unbound """
  EXISTS (SELECT 1 FROM mediate_fixture_accounts a
          WHERE a.id = current_setting('mediate.probe', true))
  """

  @doc "The table shaped like a migrations table that holds no version, because no migration ever ran against it."
  @spec empty_versions() :: String.t()
  def empty_versions, do: @versions

  @doc "Create the tables and the policies, through an owner-role repo."
  @spec create!(module()) :: :ok
  def create!(repo) when is_atom(repo) do
    _rows = repo.query!("CREATE TABLE #{@table} (id bigserial PRIMARY KEY, label text)")
    _versions = repo.query!("CREATE TABLE #{@versions} (version bigint PRIMARY KEY)")
    :ok = Migration.grant!(repo, table: @versions, to: "mediate_app", commands: [:select])
    :ok = Migration.protect!(repo, @table)
    :ok = Migration.policy!(repo, table: @table, operation: :read, using: @undeclared)
    :ok = Migration.policy!(repo, table: @table, operation: :sighted, using: @unbound)
    Migration.grant!(repo, table: @table, to: "mediate_app", commands: [:select])
  end
end

defmodule Mediate.Postgres.Probe.Row do
  @moduledoc "The probe's schema: a primary key it declares and a label it does not."

  use Ecto.Schema
  use Mediate.Schema

  @type t :: %__MODULE__{}

  schema "mediate_probe_rows" do
    field(:label, :string)
  end

  object_type(:probe_row)
end
