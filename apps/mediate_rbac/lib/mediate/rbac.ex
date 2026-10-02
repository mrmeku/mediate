defmodule Mediate.Rbac do
  @moduledoc """
  Roles in code: the engine whose policy is an Elixir module. A policy
  module, `use Mediate.Rbac.Policy`, declares the role table as data. Per
  protected schema it declares the grant rules that hold a role on its
  rows and the predicate rules every allowed row must satisfy. The
  predicates are functions in the same modules. The engine takes no
  options, so its entry in `Mediate.Config` is the bare module. It finds
  the policy module and the repo through the binding
  `Mediate.Rbac.Binding.bind/1` makes at boot beside the configuration.

  Every verdict is a query the repo runs at the time of the call. `filter`
  returns the rules as a `dynamic` over subqueries and runs nothing
  itself. The filter limit is `:infinity`. `authorize` runs one query that
  selects each rule for the row asked about. So the reason names the rule
  that allowed or the rule that failed, and the rules that held travel on
  the verdict's `meta`. A deploy is a policy version, and `release/0`
  publishes it at boot.
  """

  @behaviour Mediate.Engine

  use Boundary,
    deps: [Mediate, Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [
      Binding,
      Domain.Rules,
      Facts,
      Policy,
      Policy.Resource,
      Policy.Role,
      Policy.Rule,
      Version
    ]

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Error
  alias Mediate.PolicyRelease
  alias Mediate.Rbac.Binding
  alias Mediate.Rbac.Infrastructure.Decide
  alias Mediate.Rbac.Infrastructure.Plan
  alias Mediate.Rbac.Infrastructure.Release
  alias Mediate.Verdict

  @doc "Builds the bound policy's release and publishes it. `Mediate.Rbac.Version` says what the release holds."
  @spec release() :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def release, do: Release.publish(__MODULE__)

  @impl Mediate.Engine
  def filter_limit, do: :infinity

  @impl Mediate.Engine
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, %{now: _now} = context, _options)
      when is_atom(action) do
    with {:ok, %Binding{} = binding} <- bound(:authorize) do
      failed(Decide.one(binding, subject, action, resource, context), :authorize)
    end
  end

  @impl Mediate.Engine
  def filter({_kind, _account} = subject, action, resource_type, %{now: _now} = context, _options)
      when is_atom(action) and is_atom(resource_type) do
    with {:ok, %Binding{} = binding} <- bound(:filter) do
      filtered(Plan.build(binding.policy, subject, action, resource_type, context))
    end
  end

  defp filtered({:ok, %Plan{} = plan}), do: {:ok, {Plan.dynamic(plan), Plan.verdict(plan)}}
  defp filtered({:error, %Verdict{effect: :deny} = verdict}), do: {:ok, {dynamic([_row], false), verdict}}
  defp filtered({:error, text}) when is_binary(text), do: failed({:error, text}, :filter)

  defp failed({:error, text}, callback) when is_binary(text) do
    {:error, %Error{reason: :engine_failed, message: "#{inspect(__MODULE__)} failed during #{callback}: #{text}"}}
  end

  defp failed(other, _callback), do: other

  defp bound(callback) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, message: message}} -> failed({:error, message}, callback)
    end
  end
end
