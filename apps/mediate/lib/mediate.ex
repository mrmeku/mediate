defmodule Mediate do
  @moduledoc """
  The port: the one place an application asks whether a subject can perform
  an operation on an object. It is also the contract every adapter
  implements. The words are NIST SP 800-162's: subject, object, operation,
  and environment.

  - `authorize/4` when the call reaches the repo: it answers the decision
    the seam accepts under `mediate:`.
  - `check/4` when a branch needs a yes or no and reaches no repo.
  - `scope/4` when a query covers a whole type: it answers a `dynamic` the
    query carries, which can only narrow, and a decision whose object id is
    `nil`.
  - `review/5` when a reviewer asks who can do what today: one `scope` per
    subject under the reviewer's operation id, with `nil` ids alike.

  This module is the top-layer boundary. Everything under `Mediate` that is
  not `Mediate.Test` belongs to it. It can reach `Ecto` and `NimbleOptions`.
  It reaches nothing from `ecto_sql` or `postgrex`, because the port decides
  and does not query.
  """

  use Boundary,
    deps: [Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [
      Access,
      Adapter,
      Infrastructure.Overrides,
      Infrastructure.Seam,
      Answer,
      Change,
      Config,
      Infrastructure.Surface,
      Decision,
      Error,
      Exemption,
      Id,
      PolicyVersion,
      Port,
      Repo,
      Schema,
      Schema.Fact,
      Schema.Relationship
    ]

  alias Mediate.Decision
  alias Mediate.Error
  alias Mediate.Port

  @typedoc """
  What the subject asks about: an object type and an id. A decision over a
  whole type, which `scope/4` makes, carries `nil` for the id.
  """
  @type object :: {atom(), Mediate.Id.t() | nil}

  @typedoc """
  Under what conditions the subject asks: the facts only the caller knows,
  by name, with `now` from the configured clock beside them. The port
  stamps `now`, so a decider reads the moment of the request from the
  environment rather than from a clock of its own.
  """
  @type environment :: %{required(:now) => DateTime.t(), optional(atom()) => term()}

  @typedoc "A person, software that acts alone, or a person who can change the system."
  @type subject_kind :: :user | :non_person_entity | :privileged

  @typedoc """
  Who asks: a kind and an account id. The kind travels with every decision
  record. The port refuses a kind it does not know.
  """
  @type subject :: {subject_kind(), Mediate.Id.t()}

  @doc "Decide for one object: the decision to hand the seam, or why not."
  @spec authorize(subject(), atom(), object(), Port.options()) ::
          {:ok, Decision.t()} | {:error, Error.t()}
  defdelegate authorize(subject, operation, object, opts \\ []), to: Port

  @doc "The verdict alone for one object."
  @spec check(subject(), atom(), object(), Port.options()) :: boolean()
  defdelegate check(subject, operation, object, opts \\ []), to: Port

  @doc "The rule a row must satisfy and the decision the query carries."
  @spec scope(subject(), atom(), atom(), Port.options()) :: {Ecto.Query.dynamic_expr(), Decision.t()}
  defdelegate scope(subject, operation, object_type, opts \\ []), to: Port

  @doc "The review a reviewer asks: a rule and a decision per subject over an object type."
  @spec review(subject(), [subject()], atom(), atom(), Port.options()) :: Port.reviewed()
  defdelegate review(reviewer, subjects, operation, object_type, opts \\ []), to: Port
end
