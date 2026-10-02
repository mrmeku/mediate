defmodule ExampleRbac do
  @moduledoc """
  The example under roles in code. Nothing of the domain lives here.

  The deployment holds three things:

  - `ExampleRbac.Infrastructure.Policy`, which enforces the example's clauses
    as a role table, grant rules, and predicate rules
  - `ExampleRbac.Application`, the boot that binds the policy module to
    `Example.Infrastructure.Repo`
  - the migrations that create the example's tables
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Rbac, Ecto],
    exports: [Application, Infrastructure.Policy]
end
