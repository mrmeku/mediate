defmodule Example do
  @moduledoc """
  The example application: code hosting as a library application.
  `docs/example.md` has the clauses and the scenarios.

  - `domain/` is what the example knows. It has the schemas with their
    resource types and fact declarations, the restriction vocabulary, the
    arithmetic of clause C4, and the re-authentication window.
  - `application/` is the application modules. Each asks Mediate and
    writes through the mediated repo.
  - `infrastructure/` is the repos, the queries, the migration helper, and
    the consumer that maps the events to the OCSF records a security log
    takes.

  No module here names an engine. A deployment binds one.
  """

  use Boundary,
    deps: [
      Mediate,
      Ecto,
      Ecto.Adapters.Postgres,
      Ecto.Adapters.SQL,
      Ecto.Migration,
      NimbleOptions
    ],
    exports: [
      Application.AccessReview,
      Application.Accounts,
      Application.Proposals,
      Application.Repositories,
      Application.Repositories.OverrideRefused,
      Application.Repositories.RollupViolation,
      Domain.Account,
      Domain.Directory,
      Domain.Enterprise,
      Domain.Label,
      Domain.Membership,
      Domain.OverrideReport,
      Domain.Permission,
      Domain.Project,
      Domain.Proposal,
      Domain.Reauthentication,
      Domain.Repository,
      Domain.Restrictions,
      Domain.Rollup,
      Domain.Team,
      Domain.TeamRole,
      Domain.Visibility,
      Infrastructure.Migration,
      Infrastructure.OwnerRepo,
      Infrastructure.Repo,
      Infrastructure.SIEM
    ]

  @schemas [
    Example.Domain.Enterprise,
    Example.Domain.Team,
    Example.Domain.Project,
    Example.Domain.Label,
    Example.Domain.Account,
    Example.Domain.Permission,
    Example.Domain.Membership,
    Example.Domain.TeamRole,
    Example.Domain.Repository,
    Example.Domain.Visibility,
    Example.Domain.Directory,
    Example.Domain.Proposal,
    Example.Domain.OverrideReport
  ]

  @doc """
  Every schema of the example, in the order a migration creates their
  tables. A migration drops them in the reverse order.
  """
  @spec schemas() :: [module()]
  def schemas, do: @schemas
end
