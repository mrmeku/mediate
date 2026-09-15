defmodule Mediate.Conformance.AdapterCase do
  @moduledoc """
  The Tier 1 case template. `use Mediate.Conformance.AdapterCase,
  adapter: Mediate.Rbac, repo: Example.Infrastructure.Repo, world: Example.World`
  defines a test module. Its setup prepares the repo for the test, stubs
  the clock, and binds the adapter through the configuration override. So
  each adapter's conformance run is its own module, and all of them run in
  one `mix test`.

  The template names no schema and no rule. `world:` is a
  `Mediate.Conformance.World`. That module says what a population holds,
  what the rule over it allows, and how to write one through the seam. An
  adapter outside this repository points the template at its own tables
  and runs the same laws.

  The tests are the laws of `docs/conformance.md` §2. The name of each is
  its id and its sentence from `Mediate.Conformance.Law`. The bodies live
  in `Mediate.Conformance.AdapterCase.Laws` and its modules. The scope cap
  declaration and the fact-write shape sit beside them.

  Three laws are properties over `Mediate.Conformance.Gen`. Each iteration writes a
  population through the seam. When the adapter keeps state of its own,
  the iteration seeds that state through the `seed:` module. The
  fail-closed law needs `outage:`. The latency law needs `committed:`. The
  change-management laws need `versions:` and `committed:` both.

  Options:

  - `adapter:` the adapter module, required.
  - `repo:` the mediated repo the template writes the population through,
    required.
  - `world:` the `Mediate.Conformance.World` module, required.
  - `sandbox:` a module that answers `setup(repo, tags)`. The template
    calls it first in every test. It is for a suite whose repo needs a
    checkout, a transaction, or a row of its own before the test runs. Omit
    it for a repo that needs none.
  - `async:` default `true`, and `false` when the test gives `committed:`.
    The committed cases truncate tables every module shares.
  - `seed:` a `Mediate.Conformance.Seed` module. The template calls it
    after every population it writes. Omit it for an adapter that reads the
    world's own tables.
  - `outage:` a module whose `outage/0` makes the engine unreachable for
    the rest of the test. `ac3-05` exists only when given.
  - `setup_queries:` the queries the adapter adds to every mediated call.
    The shape laws count them. Default 0.
  - `committed:` `[repo: module, owner: module, tables: [name]]`, the
    committed and owner repos and the tables to truncate. `ac2-05` exists
    only when given.
  - `versions:` a `Mediate.Conformance.Versions` module. The `cm3` laws run
    when given. When not, they skip and print the reason. They write on the
    committed repo, so `committed:` must come with it.
  """

  alias Mediate.Conformance.AdapterCase.Laws
  alias Mediate.Conformance.Law

  @versions ~w(cm3-01 cm3-02 cm3-03 cm3-04)

  @doc false
  defmacro __using__(opts) do
    {opts, _binding} = Code.eval_quoted(opts, [], __CALLER__)

    config = %{
      adapter: Keyword.fetch!(opts, :adapter),
      repo: Keyword.fetch!(opts, :repo),
      world: Keyword.fetch!(opts, :world),
      sandbox: Keyword.get(opts, :sandbox),
      seed: Keyword.get(opts, :seed),
      outage: Keyword.get(opts, :outage),
      setup_queries: Keyword.get(opts, :setup_queries, 0),
      committed: Keyword.get(opts, :committed),
      versions: Keyword.get(opts, :versions)
    }

    if config.versions && is_nil(config.committed) do
      raise ArgumentError, "versions: needs committed: beside it, since the cm3 laws write on the committed repo"
    end

    async = Keyword.get(opts, :async, is_nil(config.committed))

    [
      preamble(config, async),
      declaration(),
      accounts(),
      access(),
      fail_closed(config.outage),
      latency(config.committed),
      audit(),
      shapes(),
      versions(config.versions)
    ]
  end

  @doc false
  @spec __setup__(map(), map()) :: {:ok, keyword()}
  def __setup__(config, tags) do
    repo = if tags[:committed], do: committed_repo!(config), else: config.repo
    if config.sandbox, do: :ok = config.sandbox.setup(repo, tags)
    if tags[:committed], do: truncate!(config)
    :ok = Mediate.Test.with_config(adapter: config.adapter, clock: &DateTime.utc_now/0)
    :ok = setup_versions(config.versions, tags)
    {:ok, adapter: config.adapter, repo: repo, case: config}
  end

  defp preamble(config, async) do
    quote do
      use ExUnit.Case, async: unquote(async)
      use ExUnitProperties

      alias Mediate.Conformance.AdapterCase.Laws
      alias Mediate.Conformance.Gen

      @moduletag adapter: unquote(config.adapter)
      @adapter_case unquote(Macro.escape(config))
      @conformance_world unquote(config.world)

      setup tags do
        unquote(__MODULE__).__setup__(@adapter_case, tags)
      end
    end
  end

  defp declaration do
    quote do
      test "the adapter declares its scope cap", %{adapter: adapter} do
        assert adapter.scope_cap() == :none or is_integer(adapter.scope_cap())
      end
    end
  end

  defp accounts, do: [account_facts(), account_review()]

  defp account_facts do
    quote do
      test unquote(Law.name("ac2-01")), context do
        Laws.Accounts.account_changes(context)
      end

      test unquote(Law.name("ac2-02")), context do
        Laws.Accounts.expiry(context)
      end

      test unquote(Law.name("ac2-03")), context do
        Laws.Accounts.disqualified(context)
      end
    end
  end

  defp account_review do
    quote do
      property unquote(Law.name("ac2-04")), context do
        check all(
                world <- Gen.world(@conformance_world),
                operation <- Gen.operation(@conformance_world),
                max_runs: 25
              ) do
          Laws.Accounts.review(context, world, operation)
        end
      end

      test unquote(Law.name("ac6-01")), context do
        Laws.Accounts.privileged_denied(context)
      end
    end
  end

  defp access, do: [rule_agreement(), deny_by_default(), scope_fidelity(), scoped_all_shape()]

  defp rule_agreement do
    quote do
      property unquote(Law.name("ac3-01")), context do
        check all(
                world <- Gen.world(@conformance_world),
                subject <- Gen.subject(world),
                operation <- Gen.operation(@conformance_world),
                object <- Gen.object(world),
                max_runs: 25
              ) do
          Laws.rule_agreement(context, world, subject, operation, object)
        end
      end
    end
  end

  defp deny_by_default do
    quote do
      property unquote(Law.name("ac3-02")), context do
        check all(
                world <- Gen.world(@conformance_world),
                subjects <- Gen.strangers(world),
                operation <- Gen.unknown_operation(),
                object <- Gen.object(world),
                max_runs: 25
              ) do
          Laws.deny_by_default(context, world, subjects, operation, object)
        end
      end
    end
  end

  defp scope_fidelity do
    quote do
      property unquote(Law.name("ac3-03")), context do
        check all(
                world <- Gen.world(@conformance_world),
                subject <- Gen.subject(world),
                operation <- Gen.operation(@conformance_world),
                max_runs: 25
              ) do
          Laws.scope_fidelity(context, world, subject, operation)
        end
      end
    end
  end

  defp scoped_all_shape do
    quote do
      test unquote(Law.name("ac3-04")), context do
        Laws.scoped_all_shape(context)
      end
    end
  end

  defp fail_closed(nil), do: []

  defp fail_closed(_outage) do
    quote do
      test unquote(Law.name("ac3-05")), context do
        Laws.fail_closed(context)
      end
    end
  end

  defp latency(nil), do: []

  defp latency(_committed) do
    quote do
      @tag :committed
      test unquote(Law.name("ac2-05")), context do
        Laws.latency(context)
      end
    end
  end

  defp audit, do: [audit_events(), audit_content(), audit_seam(), audit_refusals()]

  defp audit_events do
    quote do
      test unquote(Law.name("au2-01")), context do
        Laws.Audit.decision_events(context)
      end

      test unquote(Law.name("au2-02")), context do
        Laws.Audit.denial_reason(context)
      end

      test unquote(Law.name("au2-03")), context do
        Laws.Audit.scoped_verdicts(context)
      end
    end
  end

  defp audit_content do
    quote do
      test unquote(Law.name("au3-01")), context do
        Laws.Audit.no_attribute_value(context)
      end

      test unquote(Law.name("au3-02")), context do
        Laws.Audit.change_event(context)
      end

      test unquote(Law.name("au3-03")), context do
        Laws.Audit.access_event(context)
      end

      test unquote(Law.name("au3-04")), context do
        Laws.Audit.one_operation(context)
      end
    end
  end

  defp audit_seam do
    quote do
      test unquote(Law.name("au12-01")), context do
        Laws.Audit.inside_transaction(context)
      end

      test unquote(Law.name("au12-02")), context do
        Laws.Audit.bulk_refused(context)
      end

      test unquote(Law.name("au12-03")), context do
        Laws.Audit.around_seam(context)
      end
    end
  end

  defp audit_refusals do
    quote do
      test unquote(Law.name("au12-04")), context do
        Laws.Audit.refused_write(context)
      end

      test unquote(Law.name("au12-05")), context do
        Laws.Audit.unmediated_refused(context)
      end

      test unquote(Law.name("au12-06")), context do
        Laws.Audit.mediated_reads(context)
      end
    end
  end

  defp shapes do
    quote do
      test "shape: a single-row fact write is the write alone, and one record", context do
        Laws.fact_write_shape(context)
      end
    end
  end

  defp versions(nil) do
    for id <- @versions do
      quote do
        @tag skip: "the template was given no versions: module, so #{unquote(id)} has nothing to publish"
        test unquote(Law.name(id)), _context do
          :ok
        end
      end
    end
  end

  defp versions(_versions) do
    quote do
      @tag :committed
      test unquote(Law.name("cm3-01")), context do
        Laws.Versions.publish(context)
      end

      @tag :committed
      test unquote(Law.name("cm3-02")), context do
        Laws.Versions.version_reported(context)
      end

      @tag :committed
      test unquote(Law.name("cm3-03")), context do
        Laws.Versions.tightened_artifact(context)
      end

      @tag :committed
      test unquote(Law.name("cm3-04")), context do
        Laws.Versions.propagation(context)
      end
    end
  end

  defp setup_versions(nil, _tags), do: :ok

  defp setup_versions(versions, tags) do
    if Code.ensure_loaded?(versions) and function_exported?(versions, :setup, 1), do: versions.setup(tags), else: :ok
  end

  defp committed_repo!(%{committed: nil}) do
    raise ArgumentError, "a :committed test needs the committed: option of use Mediate.Conformance.AdapterCase"
  end

  defp committed_repo!(%{committed: committed}), do: Keyword.fetch!(committed, :repo)

  defp truncate!(%{committed: committed}) do
    owner = Keyword.fetch!(committed, :owner)
    tables = Enum.join(Keyword.fetch!(committed, :tables), ", ")

    truncate = fn ->
      owner.query!("TRUNCATE #{tables} RESTART IDENTITY CASCADE")
      :ok
    end

    :ok = truncate.()
    ExUnit.Callbacks.on_exit(truncate)
  end
end
