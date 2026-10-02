defmodule ExampleCerbos.Infrastructure.Declarations do
  @moduledoc """
  What the policy files of `priv/policies` can read: the attributes of a
  principal, of a repository, of a directory, and of a proposal, and the
  one context fact.

  A principal's two attributes are column attributes of the account row.
  So the server folds a test over either of them before it plans. The
  context fact `reauthenticated_at` reaches a policy beside the moment
  Mediate stamped the call with, as `request.principal.attr.context` (C8).

  A resource attribute a policy tests membership in is a subquery
  attribute: a query of the subject that asks, from
  `ExampleCerbos.Infrastructure.Subqueries`. The subquery selects the rows
  the value holds of, and the plan compiles the test to membership in those
  ids. So a list stays one query. A repository's `embargo` is a column
  attribute, and the moment the policy compares it with is the moment the
  call carries (C5). So the plan carries the test as a comparison on the
  row.

  Every column any of these reads is a declared fact of the example.
  `ExampleCerbos.Infrastructure.DeclarationsTest` holds it there.
  """

  use Mediate.Cerbos.Declarations

  alias Example.Domain.Account
  alias Example.Domain.Directory
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias ExampleCerbos.Infrastructure.Subqueries

  principal :user, schema: Account do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  principal :service, schema: Account do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  principal :privileged, schema: Account do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  resource :repository, schema: Repository do
    attribute :project_roles, subquery: &Subqueries.repository_project_roles/2
    attribute :team_roles, subquery: &Subqueries.repository_team_roles/2
    attribute :effective_restrictions, subquery: &Subqueries.repository_effective_restrictions/2
    attribute :releasable_to, subquery: &Subqueries.repository_releasable_to/2
    attribute :enterprise_countries, subquery: &Subqueries.repository_enterprise_countries/2
    attribute :invited, subquery: &Subqueries.repository_invited/2
    attribute :embargo, column: :embargo
  end

  resource :directory, schema: Directory do
    attribute :project_roles, subquery: &Subqueries.directory_project_roles/2
    attribute :team_roles, subquery: &Subqueries.directory_team_roles/2
    attribute :effective_restrictions, subquery: &Subqueries.directory_effective_restrictions/2
    attribute :releasable_to, subquery: &Subqueries.directory_releasable_to/2
    attribute :enterprise_countries, subquery: &Subqueries.directory_enterprise_countries/2
    attribute :invited, subquery: &Subqueries.directory_invited/2
  end

  resource :proposal, schema: Proposal do
    attribute :team_roles, subquery: &Subqueries.proposal_team_roles/2
    attribute :proposer_id, column: :proposer_id
  end

  context do
    fact(:reauthenticated_at)
  end
end
