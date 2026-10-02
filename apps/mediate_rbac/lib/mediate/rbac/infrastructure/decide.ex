defmodule Mediate.Rbac.Infrastructure.Decide do
  @moduledoc false
  # The verdict `authorize` gives: one query that selects every rule of the
  # plan for the row asked about. The query runs through the bound repo as
  # the library. It denies a row that is not there, and a subject
  # no grant reaches, with `no_rule_matched`. It denies a row that a grant
  # reaches but a predicate fails with `rule_denied` and that predicate's
  # name. It allows a row every rule allows with the name of the first
  # grant that held. A predicate that answers with neither a `dynamic` nor
  # a boolean is the error's text, and the engine names the callback it
  # failed in.
  #
  # This module rescues nothing a repo raises. The core turns any exception
  # an engine raises into a denial with `engine_failed`. So this package
  # names no driver's error, and a driver it does not carry needs no clause
  # of its own.

  import Ecto.Query, only: [from: 2]

  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Infrastructure.Plan
  alias Mediate.Verdict

  @doc "The verdict for one resource, with the rules that held under `meta[:matched]`."
  @spec one(Binding.t(), Mediate.subject(), atom(), Mediate.resource(), Mediate.context()) ::
          {:ok, Verdict.t()} | {:error, String.t()}
  def one(%Binding{} = binding, {_kind, _account} = subject, action, {type, id}, %{now: _now} = context) do
    case Plan.build(binding.policy, subject, action, type, context) do
      {:ok, %Plan{} = plan} -> {:ok, decided(plan, row(binding.repo, plan, id))}
      {:error, %Verdict{} = verdict} -> {:ok, matched(verdict, [])}
      {:error, text} when is_binary(text) -> {:error, text}
    end
  end

  defp row(repo, %Plan{schema: schema} = plan, id) do
    key = Plan.primary_key(schema)
    query = from(row in schema, where: field(row, ^key) == ^id, select: ^Plan.rules(plan))
    repo.one(query, authorized_by: {:exempt, :library})
  end

  defp decided(%Plan{policy_version: version}, nil), do: matched(Plan.deny(:no_rule_matched, version), [])

  defp decided(%Plan{grants: grants, predicates: predicates, policy_version: version}, row) do
    held = fn {name, _expression} -> row[name] == true end
    held_names = for {name, _expression} = rule <- grants ++ predicates, held.(rule), do: Atom.to_string(name)
    verdict = verdict(Enum.find(grants, held), Enum.reject(predicates, held), version)
    matched(verdict, held_names)
  end

  defp verdict(nil, _failed, version), do: Plan.deny(:no_rule_matched, version)

  defp verdict(_granted, [{name, _expression} | _rest], version) do
    Plan.deny(:rule_denied, version, %{rule: Atom.to_string(name)})
  end

  defp verdict({name, _expression}, [], version) do
    %Verdict{effect: :allow, reason: :rule_allowed, policy_version: version, meta: %{rule: Atom.to_string(name)}}
  end

  defp matched(%Verdict{} = verdict, names), do: %{verdict | meta: Map.put(verdict.meta, :matched, names)}
end
