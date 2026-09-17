defmodule Example do
  @moduledoc """
  The example application: code hosting as a library application.
  `docs/example.md` has the rules and the scenarios.

  - `domain/` is what the example knows. It has the schemas with their
    object types and fact declarations, the restriction vocabulary, the
    arithmetic of rule C4, and the re-authentication window.
  - `application/` is the contexts. Each calls the port and writes through
    the seam.
  - `infrastructure/` is the repos, the queries, the migration helper, and
    the consumer that maps the events to the shape a security log takes.

  No module here names an adapter. A thin application binds one.
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
      Application.Accounts,
      Application.Proposals,
      Application.Repositories,
      Application.Repositories.OverrideRefused,
      Application.Repositories.RollupViolation,
      Application.Review,
      Domain.AccountRole,
      Domain.Directory,
      Domain.Enterprise,
      Domain.Label,
      Domain.Membership,
      Domain.OverrideReport,
      Domain.Project,
      Domain.Proposal,
      Domain.Repository,
      Domain.Restrictions,
      Domain.Rollup,
      Domain.Sessions,
      Domain.Team,
      Domain.TeamRole,
      Domain.User,
      Domain.Visibility,
      Infrastructure.Migration,
      Infrastructure.OwnerRepo,
      Infrastructure.Repo,
      Infrastructure.Siem
    ]

  @schemas [
    Example.Domain.Enterprise,
    Example.Domain.Team,
    Example.Domain.Project,
    Example.Domain.Label,
    Example.Domain.User,
    Example.Domain.AccountRole,
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
