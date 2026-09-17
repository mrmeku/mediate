defmodule ExampleCerbos.Infrastructure.Attributes do
  @moduledoc """
  What the policies of `priv/policies` can read: the attributes of a
  principal, of a repository, of a directory, and of a proposal.

  A principal's two attributes are columns of the account row. So the
  sidecar folds a test over either of them before it plans anything. The
  request-time fact `reauthenticated_at` reaches the policies beside the
  moment the port stamped the request with (C8).

  A resource attribute a policy tests membership in is a subquery of the
  subject that asks (`ExampleCerbos.Infrastructure.Facts`). The subquery
  selects the rows the value holds of, and the plan compiles the test to
  membership in those ids. So a list stays one query. A repository's
  `embargo` is a column instead. The moment the policy compares it
  against is the moment the request carries (C5). So the plan carries the
  test as a comparison on the row.

  Every column any of these reads is a declared fact of the example.
  `ExampleCerbos.CoverageTest` holds it there.
  """

  use Mediate.Cerbos.Attributes

  alias Example.Domain.Directory
  alias Example.Domain.Proposal
  alias Example.Domain.Repository
  alias Example.Domain.User
  alias ExampleCerbos.Infrastructure.Facts

  principal :user, schema: User do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  principal :non_person_entity, schema: User do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  principal :privileged, schema: User do
    attribute :employment, column: :employment
    attribute :country, column: :country
  end

  resource :repository, schema: Repository do
    attribute :project_roles, subquery: &Facts.project_roles/2
    attribute :team_roles, subquery: &Facts.team_roles/2
    attribute :effective_restrictions, subquery: &Facts.effective_restrictions/2
    attribute :releasable_to, subquery: &Facts.releasable_to/2
    attribute :enterprise_countries, subquery: &Facts.enterprise_countries/2
    attribute :invited, subquery: &Facts.invited/2
    attribute :embargo, column: :embargo
  end

  resource :directory, schema: Directory do
    attribute :project_roles, subquery: &Facts.directory_project_roles/2
    attribute :team_roles, subquery: &Facts.directory_team_roles/2
    attribute :effective_restrictions, subquery: &Facts.directory_effective_restrictions/2
    attribute :releasable_to, subquery: &Facts.directory_releasable_to/2
    attribute :enterprise_countries, subquery: &Facts.directory_enterprise_countries/2
    attribute :invited, subquery: &Facts.directory_invited/2
  end

  resource :proposal, schema: Proposal do
    attribute :team_roles, subquery: &Facts.proposal_team_roles/2
    attribute :proposer_id, column: :proposer_id
  end

  environment do
    fact(:reauthenticated_at)
  end
end
