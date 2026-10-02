defmodule Mediate.Conformance.Specimen do
  @moduledoc """
  What an adopter gives `Mediate.Conformance.RepoCase` so the case can
  hold a repo to the five repo requirements the identity write and
  resource read events make:

  - a row of one identity schema
  - a change to one of its fact fields
  - the decision or exemption those writes carry
  - the way this deployment writes the same row around the mediated repo
  - a row of one protected schema, with a decision that admits a read of
    it

  The schema's table has to exist, because the case writes to it. A repo
  swept without a database leaves the option out and proves the refusals
  alone.
  """

  @doc """
  Whatever a test needs in place first: the connection, the configuration,
  and the rows the identity schema refers to. The tags are the test's. An
  adopter that needs none of it defines this not at all.
  """
  @callback setup(tags :: map()) :: :ok

  @doc "An unwritten row of an identity schema. Each call answers one the case can write beside the ones before it."
  @callback identity_row() :: struct()

  @doc "A changeset of a written row that sets at least one fact field to a value the row does not hold."
  @callback fact_changeset(struct()) :: Ecto.Changeset.t()

  @doc "The `authorized_by:` option those writes carry: a decision that admits the schema, or a declared exemption."
  @callback authorized_by() :: term()

  @doc "Change a fact field of the written row around the mediated repo, as a patch applied by hand does."
  @callback write_around(struct()) :: :ok

  @doc "An unwritten row of a protected schema, one that declares a resource type, for the resource read requirement."
  @callback protected_row() :: struct()

  @doc "A decision from `Mediate.authorize/4` that admits a read of the written row of `protected_row/0`."
  @callback read_decision(struct()) :: Mediate.Decision.t()

  @optional_callbacks setup: 1
end
