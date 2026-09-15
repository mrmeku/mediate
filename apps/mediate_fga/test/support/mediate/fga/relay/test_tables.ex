defmodule Mediate.Fga.Relay.TestTables do
  @moduledoc """
  The two tables the test job works over, and the application role's
  grants, which `create!/1` raises through an owner-role repo. One holds
  the rows a runner ships, the other what reached the far end. Neither is
  anything this package ships. Where rows live is the job's.
  """

  use Boundary, top_level?: true, deps: []

  @rows "mediate_relay_test_rows"
  @sent "mediate_relay_test_sent"

  @tables [
    "CREATE TABLE mediate_relay_test_rows (id bigserial PRIMARY KEY, runner text NOT NULL, body text NOT NULL)",
    "CREATE TABLE mediate_relay_test_sent (id bigserial PRIMARY KEY, runner text NOT NULL, " <>
      "position bigint NOT NULL, tag text NOT NULL)",
    "CREATE UNIQUE INDEX mediate_relay_test_sent_once ON mediate_relay_test_sent (runner, position)"
  ]

  @doc "The table a runner reads the rows it ships from."
  @spec rows() :: String.t()
  def rows, do: @rows

  @doc "The table a delivery lands in, one row per entry that reached the far end."
  @spec sent() :: String.t()
  def sent, do: @sent

  @doc "Creates the tables. The repo is an owner-role repo whose calls carry the library exemption."
  @spec create!(module()) :: :ok
  def create!(repo) when is_atom(repo) do
    Enum.each(@tables, &repo.query!/1)

    Enum.each([@rows, @sent], fn name ->
      repo.query!("GRANT SELECT, INSERT, UPDATE, DELETE ON #{name} TO mediate_app")
      repo.query!("GRANT USAGE, SELECT ON SEQUENCE #{name}_id_seq TO mediate_app")
    end)

    :ok
  end
end
