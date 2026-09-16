defmodule ExampleCerbos do
  @moduledoc """
  The example bound to a policy sidecar. Nothing of the domain lives here.

  The package holds:

  - the attribute declarations, which say what the policies can read
  - the subqueries behind them
  - the policy files the sidecar serves
  - the boot, which binds them to `Example.Infrastructure.Repo`
  - the migrations, which create the example's tables

  A directory of policy files carries no history. The `version` field
  inside a policy file runs variants side by side and not one after
  another. So the version identifier is the commit of the repository the
  files come from (`Mediate.Cerbos.Version`). The commit arrives as
  configuration: `POLICY_COMMIT` in a deployment, a pinned string in the
  test configuration. A published version carries the files as its content
  under the cap.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Cerbos, Ecto],
    exports: [Application, Infrastructure.Attributes, Infrastructure.Facts]

  @author "example_cerbos"
  @approval "the rules in docs/example.md, as policy files under review"

  @doc "Who wrote the rules, as the record of a policy version carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved them, as the record of a policy version carries it."
  @spec approval() :: String.t()
  def approval, do: @approval
end
