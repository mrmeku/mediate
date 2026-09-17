defmodule ExampleRbac.Infrastructure.Policy do
  @moduledoc """
  The example's rules as a role table and, per protected schema, the grants
  and predicates. `docs/example.md` states the rules.

  The grants:

  - a project role reaches a repository through its open project (C1), and a
    directory through its repository
  - a team role reaches a repository through its owning team
    (C1, C7), and a proposal through the repository's team (C9)

  The predicates:

  - `:restrictions` is C2, C3, C5, and C6 in one subquery
  - `:session` is C8
  - `:another_reviewer` is C9
  """

  use Mediate.Rbac.Policy, version: "2026.09.1", author: "example_rbac", approval: "the rules in docs/example.md"

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

  object Repository do
    grant :membership, Membership, on: :project_id, through: [{Project, :id, where: &Predicates.open/0}]
    grant :team, TeamRole, on: :owning_team_id
    predicate :restrictions, &Predicates.restrictions/2, only: [:read]
    predicate :session, &Predicates.session/2, only: [:change_visibility, :set_embargo, :lift_embargo]
  end

  object Directory do
    grant :membership, Membership,
      on: :repository_id,
      through: [{Repository, :project_id}, {Project, :id, where: &Predicates.open/0}]

    grant :team, TeamRole, on: :repository_id, through: [{Repository, :owning_team_id}]
    predicate :restrictions, &Predicates.directory_restrictions/2, only: [:read]
    predicate :session, &Predicates.session/2, only: [:change_visibility]
  end

  object Proposal do
    grant :team, TeamRole, on: :repository_id, through: [{Repository, :owning_team_id}]
    predicate :another_reviewer, &Predicates.another_reviewer/2, only: [:approve_visibility]
  end
end
