defmodule ExamplePostgres do
  @moduledoc """
  The example under row-level security. Nothing of the domain lives here.

  The deployment holds three things:

  - `ExamplePostgres.Infrastructure.Policy`, the example's clauses as the
    expressions the rules are written from
  - the migrations, which reassign the protected tables to the owner role,
    write the rules and release the policy
  - `ExamplePostgres.Application`, the boot that binds the example's schemas
    to `Example.Infrastructure.Repo`

  `Mediate.Postgres.Version` says what a policy version is. The policy
  migration releases one from the rules it wrote, in its own transaction, so
  there is no release at the boot.
  """

  use Boundary,
    deps: [Example, Mediate, Mediate.Postgres, Ecto],
    exports: [Application, Infrastructure.Policy]

  @author "the Mediate maintainers"
  @approval "the thirteen clauses of docs/example.md"
  @policy_text_bytes 65_536

  @doc "Who wrote the policy, as the policy release carries it."
  @spec author() :: String.t()
  def author, do: @author

  @doc "What approved it, as the policy release carries it."
  @spec approval() :: String.t()
  def approval, do: @approval

  @doc "The cap on the policy text a release carries, as the release helper's `policy_text_bytes:`."
  @spec policy_text_bytes() :: pos_integer()
  def policy_text_bytes, do: @policy_text_bytes
end
