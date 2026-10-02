defmodule Mediate.Conformance.EngineCase do
  @moduledoc """
  The engine case. `use Mediate.Conformance.EngineCase, engine: Mediate.Rbac,
  repo: Example.Infrastructure.Repo, world: Example.World` defines a test
  module. Its setup prepares the repo for the test, stubs the clock, and
  binds the engine through the configuration override. So each engine's
  conformance run is its own module in its own package, and each package's
  suite is its own OS process. Every engine in this repository passes
  `async: false`, `setup:`, `queries_per_call:`, `durable:`, and `policy:`.
  Cerbos, OpenFGA, and Postgres pass `outage:`, and OpenFGA passes
  `mirror:`.

  The case names no schema and no rule. `world:` is a
  `Mediate.Conformance.World`. That module says what a world holds, what
  the rule over it allows, and how to write one through the mediated repo.
  An engine outside this repository points the case at its own tables and
  runs the same requirements.

  The tests are the engine requirements of
  [the conformance document](https://hexdocs.pm/mediate/conformance.html).
  The name of each is its id and its text from
  `Mediate.Conformance.Requirement`. The procedures live in
  `Mediate.Conformance.Procedure` and its modules. The filter limit
  declaration and the grant write budget sit beside them.

  Three requirements are properties over `Mediate.Conformance.Generators`.
  Each iteration writes a world through the mediated repo. When the engine
  keeps state of its own, the iteration mirrors that state through the
  `mirror:` module. The fail-closed requirement needs `outage:`. The
  latency requirement needs `durable:`. The change-management requirements
  need `policy:` and `durable:` both.

  Options:

  - `engine:` the engine module, required.
  - `repo:` the mediated repo the case writes the world through, required.
  - `world:` the `Mediate.Conformance.World` module, required.
  - `setup:` a module that answers `setup(repo, tags)`. The case calls it
    first in every test. It is for a suite whose repo needs a checkout, a
    transaction, or a row of its own before the test runs. Omit it for a
    repo that needs none.
  - `async:` default `true`, and `false` when the test gives `durable:`.
    The durable tests truncate tables every module shares.
  - `mirror:` a `Mediate.Conformance.Mirror` module. The case calls it
    after every world it writes. Omit it for an engine that reads the
    world's own tables.
  - `outage:` a `Mediate.Conformance.Outage` module. `ac3-05` exists only
    when given.
  - `queries_per_call:` the queries the engine adds to every mediated
    call. The budget tests count them. Default 0.
  - `durable:` `[repo: module, owner: module, tables: [name]]`, the durable
    and owner repos and the tables to truncate. `ac2-05` exists only when
    given.
  - `policy:` a `Mediate.Conformance.Policy` module. The `cm3`
    requirements run when given. When not, they skip and print the reason.
    They write on the durable repo, so `durable:` must come with it.
  """

  alias Mediate.Conformance.Procedure
  alias Mediate.Conformance.Requirement

  @change ~w(cm3-01 cm3-02 cm3-03 cm3-04)

  @doc false
  defmacro __using__(opts) do
    {opts, _binding} = Code.eval_quoted(opts, [], __CALLER__)

    config = %{
      engine: Keyword.fetch!(opts, :engine),
      repo: Keyword.fetch!(opts, :repo),
      world: Keyword.fetch!(opts, :world),
      setup: Keyword.get(opts, :setup),
      mirror: Keyword.get(opts, :mirror),
      outage: Keyword.get(opts, :outage),
      queries_per_call: Keyword.get(opts, :queries_per_call, 0),
      durable: Keyword.get(opts, :durable),
      policy: Keyword.get(opts, :policy)
    }

    if config.policy && is_nil(config.durable) do
      raise ArgumentError, "policy: needs durable: beside it, since the cm3 requirements write on the durable repo"
    end

    async = Keyword.get(opts, :async, is_nil(config.durable))

    [
      preamble(config, async),
      declaration(),
      accounts(),
      access(),
      fail_closed(config.outage),
      latency(config.durable),
      audit(),
      budget(),
      change(config.policy)
    ]
  end

  @doc false
  @spec __setup__(map(), map()) :: {:ok, keyword()}
  def __setup__(config, tags) do
    repo = if tags[:durable], do: durable_repo!(config), else: config.repo
    if config.setup, do: :ok = config.setup.setup(repo, tags)
    if tags[:durable], do: truncate!(config)
    :ok = Mediate.Test.with_config(engine: config.engine, clock: &DateTime.utc_now/0)
    :ok = setup_policy(config.policy, tags)
    {:ok, engine: config.engine, repo: repo, conformance: config}
  end

  defp preamble(config, async) do
    quote do
      use ExUnit.Case, async: unquote(async)
      use ExUnitProperties

      alias Mediate.Conformance.Generators
      alias Mediate.Conformance.Procedure

      @moduletag engine: unquote(config.engine)
      @engine_case unquote(Macro.escape(config))
      @conformance_world unquote(config.world)

      setup tags do
        unquote(__MODULE__).__setup__(@engine_case, tags)
      end
    end
  end

  defp declaration do
    quote do
      test "the engine declares its filter limit", %{engine: engine} do
        assert engine.filter_limit() == :infinity or is_integer(engine.filter_limit())
      end
    end
  end

  defp accounts, do: [account_facts(), account_review()]

  defp account_facts do
    quote do
      test unquote(Requirement.test_name("ac2-01")), context do
        Procedure.Accounts.ac2_01(context)
      end

      test unquote(Requirement.test_name("ac2-02")), context do
        Procedure.Accounts.ac2_02(context)
      end

      test unquote(Requirement.test_name("ac2-03")), context do
        Procedure.Accounts.ac2_03(context)
      end
    end
  end

  defp account_review do
    quote do
      property unquote(Requirement.test_name("ac2-04")), context do
        check all(
                world <- Generators.world(@conformance_world),
                action <- Generators.action(@conformance_world),
                max_runs: 25
              ) do
          Procedure.Accounts.ac2_04(context, world, action)
        end
      end

      test unquote(Requirement.test_name("ac6-01")), context do
        Procedure.Accounts.ac6_01(context)
      end
    end
  end

  defp access, do: [rule_agreement(), deny_by_default(), filter_fidelity(), filter_budget()]

  defp rule_agreement do
    quote do
      property unquote(Requirement.test_name("ac3-01")), context do
        check all(
                world <- Generators.world(@conformance_world),
                subject <- Generators.subject(world),
                action <- Generators.action(@conformance_world),
                resource <- Generators.resource(world),
                max_runs: 25
              ) do
          Procedure.ac3_01(context, world, subject, action, resource)
        end
      end
    end
  end

  defp deny_by_default do
    quote do
      property unquote(Requirement.test_name("ac3-02")), context do
        check all(
                world <- Generators.world(@conformance_world),
                subjects <- Generators.deny_by_default_subjects(world),
                action <- Generators.unknown_action(),
                resource <- Generators.resource(world),
                max_runs: 25
              ) do
          Procedure.ac3_02(context, world, subjects, action, resource)
        end
      end
    end
  end

  defp filter_fidelity do
    quote do
      property unquote(Requirement.test_name("ac3-03")), context do
        check all(
                world <- Generators.world(@conformance_world),
                subject <- Generators.subject(world),
                action <- Generators.action(@conformance_world),
                max_runs: 25
              ) do
          Procedure.ac3_03(context, world, subject, action)
        end
      end
    end
  end

  defp filter_budget do
    quote do
      test unquote(Requirement.test_name("ac3-04")), context do
        Procedure.ac3_04(context)
      end
    end
  end

  defp fail_closed(nil), do: []

  defp fail_closed(_outage) do
    quote do
      test unquote(Requirement.test_name("ac3-05")), context do
        Procedure.ac3_05(context)
      end
    end
  end

  defp latency(nil), do: []

  defp latency(_durable) do
    quote do
      @tag :durable
      test unquote(Requirement.test_name("ac2-05")), context do
        Procedure.ac2_05(context)
      end
    end
  end

  defp audit, do: [audit_events(), audit_content(), audit_writes(), audit_refusals()]

  defp audit_events do
    quote do
      test unquote(Requirement.test_name("au2-01")), context do
        Procedure.Audit.au2_01(context)
      end

      test unquote(Requirement.test_name("au2-02")), context do
        Procedure.Audit.au2_02(context)
      end

      test unquote(Requirement.test_name("au2-03")), context do
        Procedure.Audit.au2_03(context)
      end
    end
  end

  defp audit_content do
    quote do
      test unquote(Requirement.test_name("au3-01")), context do
        Procedure.Audit.au3_01(context)
      end

      test unquote(Requirement.test_name("au3-02")), context do
        Procedure.Audit.au3_02(context)
      end

      test unquote(Requirement.test_name("au3-03")), context do
        Procedure.Audit.au3_03(context)
      end

      test unquote(Requirement.test_name("au3-04")), context do
        Procedure.Audit.au3_04(context)
      end
    end
  end

  defp audit_writes do
    quote do
      test unquote(Requirement.test_name("au12-01")), context do
        Procedure.Audit.au12_01(context)
      end

      test unquote(Requirement.test_name("au12-02")), context do
        Procedure.Audit.au12_02(context)
      end

      test unquote(Requirement.test_name("au12-03")), context do
        Procedure.Audit.au12_03(context)
      end
    end
  end

  defp audit_refusals do
    quote do
      test unquote(Requirement.test_name("au12-04")), context do
        Procedure.Audit.au12_04(context)
      end

      test unquote(Requirement.test_name("au12-05")), context do
        Procedure.Audit.au12_05(context)
      end

      test unquote(Requirement.test_name("au12-06")), context do
        Procedure.Audit.au12_06(context)
      end
    end
  end

  defp budget do
    quote do
      test "budget: a single-row grant write is one insert and one identity write event", context do
        Procedure.grant_write_budget(context)
      end
    end
  end

  defp change(nil) do
    for id <- @change do
      quote do
        @tag skip: "the case was given no policy: module, so #{unquote(id)} has nothing to release"
        test unquote(Requirement.test_name(id)), _context do
          :ok
        end
      end
    end
  end

  defp change(_policy) do
    quote do
      @tag :durable
      test unquote(Requirement.test_name("cm3-01")), context do
        Procedure.Change.cm3_01(context)
      end

      @tag :durable
      test unquote(Requirement.test_name("cm3-02")), context do
        Procedure.Change.cm3_02(context)
      end

      @tag :durable
      test unquote(Requirement.test_name("cm3-03")), context do
        Procedure.Change.cm3_03(context)
      end

      @tag :durable
      test unquote(Requirement.test_name("cm3-04")), context do
        Procedure.Change.cm3_04(context)
      end
    end
  end

  defp setup_policy(nil, _tags), do: :ok

  defp setup_policy(policy, tags) do
    if Code.ensure_loaded?(policy) and function_exported?(policy, :setup, 1), do: policy.setup(tags), else: :ok
  end

  defp durable_repo!(%{durable: nil}) do
    raise ArgumentError, "a :durable test needs the durable: option of use Mediate.Conformance.EngineCase"
  end

  defp durable_repo!(%{durable: durable}), do: Keyword.fetch!(durable, :repo)

  defp truncate!(%{durable: durable}) do
    owner = Keyword.fetch!(durable, :owner)
    tables = Enum.join(Keyword.fetch!(durable, :tables), ", ")

    truncate = fn ->
      owner.query!("TRUNCATE #{tables} RESTART IDENTITY CASCADE")
      :ok
    end

    :ok = truncate.()
    ExUnit.Callbacks.on_exit(truncate)
  end
end
