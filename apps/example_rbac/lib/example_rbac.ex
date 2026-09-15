defmodule ExampleRbac do
  @moduledoc """
  The example bound to RBAC in code. Nothing of the domain lives here.

  The package holds three things:

  - `ExampleRbac.Infrastructure.Policy`, which states the example's rules as
    a role table, grants, and predicates
  - `ExampleRbac.Application`, the boot that binds the policy to
    `Example.Infrastructure.Repo`
  - the migrations that create the example's tables
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Rbac, Ecto],
    exports: [Application, Infrastructure.Policy]
end
