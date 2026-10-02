defmodule ExampleCerbos do
  @moduledoc """
  The example under policy files. Nothing of the domain lives here.

  The deployment holds four things:

  - `ExampleCerbos.Infrastructure.Declarations`, which says what a policy
    file can read
  - `ExampleCerbos.Infrastructure.Subqueries`, the subquery behind each
    attribute whose value depends on who asks
  - the policy files under `priv/policies`, which a Cerbos server serves
  - `ExampleCerbos.Application`, the boot that binds them to
    `Example.Infrastructure.Repo`, and the migrations, which raise the
    example's tables

  A directory of policy files carries no history, and the `version` field
  inside a policy file runs variants side by side. So the policy version is
  the commit of the repository the files come from, which
  `Mediate.Cerbos.Version` says. The commit arrives as configuration:
  `POLICY_COMMIT` in a deployment, a pinned string in the test
  configuration. The policy release carries the files as its text, under
  the cap.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Cerbos, Ecto],
    exports: [Application, Infrastructure.Declarations, Infrastructure.Subqueries]

  @author "the Mediate maintainers"
  @approval "the thirteen clauses of docs/example.md"

  @doc "Who wrote the policy, as the policy release carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved it, as the policy release carries it."
  @spec approval() :: String.t()
  def approval, do: @approval
end
