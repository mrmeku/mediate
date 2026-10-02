defmodule Mediate.Postgres.Infrastructure.Decide do
  # What the engine asks the database. One statement per decision, under
  # the session settings. Where the action has a gate rule, the statement
  # selects the gate's `USING` expression for the row in question:
  #
  #     SELECT coalesce((<gate expression>), false)
  #     FROM <table> WHERE id::text = $1
  #
  # Visibility answers the read. The filter rule of the action narrows
  # the statement, so a row that comes back is one the subject can see
  # under that action. A row that does not come back is a denial, and the
  # database cannot tell a hidden row from an absent one. The gate
  # answers the write. Its expression is the one the database applies
  # through `WITH CHECK` when the write runs. So a verdict given before a
  # write agrees with what the write meets.
  #
  # The statement names the table with no alias, because the database
  # renders a rule's references to its own table qualified by that
  # table's name. It compares primary keys as text, so an integer key and
  # a string key ask the same question. Neither the resource's id type nor
  # the schema's matters here.
  #
  # This module rescues nothing a repo raises. The core turns any
  # exception an engine raises into the engine failure that denies. So
  # this package names no driver's error, and a driver it does not carry
  # needs no clause of its own.
  @moduledoc false

  alias Mediate.Postgres.Binding
  alias Mediate.Postgres.Catalog
  alias Mediate.Postgres.Domain.Identifier
  alias Mediate.Postgres.Domain.Settings
  alias Mediate.Postgres.Infrastructure.Session
  alias Mediate.Postgres.Rule
  alias Mediate.Verdict

  @exemption {:exempt, :library}

  @doc "The verdict for one resource, under the settings of the call, which the session remembers."
  @spec one(Binding.t(), Catalog.t(), Mediate.subject(), atom(), Mediate.resource(), Mediate.context()) ::
          {:ok, Verdict.t()}
  def one(
        %Binding{} = binding,
        %Catalog{} = catalog,
        {_kind, _account} = subject,
        action,
        {type, id},
        %{now: _now} = context
      )
      when is_atom(action) do
    settings = remembered(subject, action, context)
    {:ok, Session.run(binding.repo, settings, fn -> of_type(binding, catalog, action, type, id) end)}
  end

  @doc """
  The verdict a filter gets. The rule the core records is `true`, because
  the filter rule of the action narrows the query when it runs. The
  verdict's `meta` names that rule and the hash of the settings the
  database reads, which together are what it enforced. A resource type no
  bound schema declares matches no rule. An action with no filter rule on
  the type is unknown.
  """
  @spec filter(Binding.t(), Catalog.t(), atom(), atom(), Settings.t()) :: Verdict.t()
  def filter(%Binding{} = binding, %Catalog{} = catalog, action, resource_type, %Settings{} = settings)
      when is_atom(action) and is_atom(resource_type) do
    case Binding.table_of(binding, resource_type) do
      {table, _key} -> filtered(catalog, Catalog.filter_rule(catalog, table, action), settings)
      nil -> verdict(catalog, :deny, :no_rule_matched, %{resource_type: resource_type})
    end
  end

  defp filtered(catalog, %Rule{name: name}, settings) do
    verdict(catalog, :allow, :rule_allowed, %{rule: name, settings_hash: Settings.hash(settings)})
  end

  defp filtered(catalog, nil, _settings), do: verdict(catalog, :deny, :action_unknown)

  defp remembered(subject, action, context) do
    settings = Settings.new(subject, action, context)
    :ok = Session.remember(subject, action, settings)
    settings
  end

  defp of_type(binding, catalog, action, type, id) do
    case Binding.table_of(binding, type) do
      {_table, _key} = target -> against(binding, catalog, action, target, id)
      nil -> verdict(catalog, :deny, :no_rule_matched, %{resource_type: type})
    end
  end

  defp against(binding, catalog, action, {table, _key} = target, id) do
    case Catalog.filter_rule(catalog, table, action) do
      %Rule{} = filter -> answered(binding, catalog, action, target, filter, id)
      nil -> verdict(catalog, :deny, :action_unknown)
    end
  end

  defp answered(binding, catalog, action, {table, _key} = target, filter, id) do
    gate = Catalog.gate_rule(catalog, table, action)
    answer(catalog, filter, gate, admitted(binding, target, gate, to_string(id)))
  end

  defp admitted(%Binding{repo: repo}, {table, key}, gate, id) do
    column = Identifier.check!(key, :primary_key)
    from = Identifier.check!(table, :table)
    statement = "SELECT #{predicate(gate)} FROM #{from} WHERE #{column}::text = $1"

    case repo.query!(statement, [id], authorized_by: @exemption) do
      %{rows: [[admitted]]} -> {:ok, admitted}
      %{rows: []} -> :error
    end
  end

  defp predicate(%Rule{using: using}) when is_binary(using), do: "coalesce((#{using}), false)"
  defp predicate(_ungated), do: "true"

  defp answer(catalog, filter, _gate, {:ok, true}), do: verdict(catalog, :allow, :rule_allowed, %{rule: filter.name})

  defp answer(catalog, filter, gate, {:ok, _refused}) do
    verdict(catalog, :deny, :rule_denied, %{rule: refusing(gate, filter)})
  end

  defp answer(catalog, filter, _gate, :error), do: verdict(catalog, :deny, :rule_denied, %{rule: filter.name})

  defp refusing(%Rule{name: name}, _filter), do: name
  defp refusing(nil, %Rule{name: name}), do: name

  defp verdict(%Catalog{policy_version: policy_version}, effect, reason, meta \\ %{}) do
    %Verdict{effect: effect, reason: reason, policy_version: policy_version, meta: meta}
  end
end
