defmodule Example do
  @moduledoc """
  The example application: controlled unclassified information as a
  library application. `docs/example.md` has the rules and the scenarios.

  - `domain/` is what the example knows. It has the schemas with their
    object types and fact declarations, the control vocabulary, the
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
      Application.Documents,
      Application.Documents.BannerViolation,
      Application.Documents.OverrideRefused,
      Application.Proposals,
      Application.Review,
      Domain.AccountRole,
      Domain.Agency,
      Domain.Assignment,
      Domain.Banner,
      Domain.Category,
      Domain.Controls,
      Domain.Document,
      Domain.Marking,
      Domain.Office,
      Domain.OfficeRole,
      Domain.OverrideReport,
      Domain.Portion,
      Domain.Program,
      Domain.Proposal,
      Domain.Sessions,
      Domain.User,
      Infrastructure.Migration,
      Infrastructure.OwnerRepo,
      Infrastructure.Repo,
      Infrastructure.Siem
    ]

  @schemas [
    Example.Domain.Agency,
    Example.Domain.Office,
    Example.Domain.Program,
    Example.Domain.Category,
    Example.Domain.User,
    Example.Domain.AccountRole,
    Example.Domain.Assignment,
    Example.Domain.OfficeRole,
    Example.Domain.Document,
    Example.Domain.Marking,
    Example.Domain.Portion,
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
