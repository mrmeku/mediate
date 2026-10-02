defmodule ExampleRbac.Infrastructure.Policy do
  @moduledoc """
  The example's clauses as a role table and, per protected schema, the grant
  rules and predicate rules that enforce them. `docs/example.md` states the
  clauses.

  The grant rules:

  - `:membership` reaches a repository through its project, when the project
    is not archived (C1), and a directory through its repository
  - `:team_role` reaches a repository through its owning team (C1, C7), and a
    proposal through the repository's team (C9)

  The predicate rules:

  - `:restrictions` is C2, C3, C5, and C6 in one subquery
  - `:fresh_session` is C8
  - `:another_reviewer` is C9
  """

  use Mediate.Rbac.Policy,
    version: "2026.09.1",
    author: "the Mediate maintainers",
    approval: "the thirteen clauses of docs/example.md"

  alias Example.Domain.Directory
  alias Example.Domain.Membership
  alias Example.Domain.Project
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.TeamRole
  alias ExampleRbac.Infrastructure.Predicates

  role :contributor, [:read, :checkout]
  role :maintainer, [:read, :checkout]
  role :admin, [:read, :checkout, :change_visibility, :set_embargo, :lift_embargo, :propose_visibility]
  role :reviewer, [:read, :checkout, :approve_visibility]

  resource Repository do
    grant :membership, Membership, on: :project_id, through: [{Project, :id, where: &Predicates.not_archived/0}]
    grant :team_role, TeamRole, on: :owning_team_id
    predicate :restrictions, &Predicates.repository_restrictions/2, actions: [:read]
    predicate :fresh_session, &Predicates.fresh_session/2, actions: [:change_visibility, :set_embargo, :lift_embargo]
  end

  resource Directory do
    grant :membership, Membership,
      on: :repository_id,
      through: [{Repository, :project_id}, {Project, :id, where: &Predicates.not_archived/0}]

    grant :team_role, TeamRole, on: :repository_id, through: [{Repository, :owning_team_id}]
    predicate :restrictions, &Predicates.directory_restrictions/2, actions: [:read]
    predicate :fresh_session, &Predicates.fresh_session/2, actions: [:change_visibility]
  end

  resource Proposal do
    grant :team_role, TeamRole, on: :repository_id, through: [{Repository, :owning_team_id}]
    predicate :another_reviewer, &Predicates.another_reviewer/2, actions: [:approve_visibility]
  end
end
