defmodule Mediate.Cerbos do
  @moduledoc """
  The Cerbos adapter: the rules are policy files, and a sidecar on the same
  host answers from them.

  The configuration boots with `adapter: {Mediate.Cerbos, address: "127.0.0.1:3592"}`
  (`docs/design.md` §7). The entry carries the sidecar's `address:` and
  nothing else, because the address is where the process runs. What the
  adapter can read comes from the binding that `Mediate.Cerbos.Binding.bind/1`
  makes at boot. The binding names the mediated repo, the declaration
  module, the policy directory, and the commit of that directory.

  Every call reads the declared attribute values through the bound repo,
  then asks the sidecar once. `decide` asks for a decision over the row
  the object names. Its answer names the policy the sidecar matched.
  `scope` asks for a query plan and compiles the plan's filter into a
  `dynamic` over the object type. A plan this adapter does not express
  fails `scope` and emits `[:mediate, :cerbos, :scope_fallback]`. The port
  then answers that scope as a denial.

  This adapter implements no `around_query/3`, because a sidecar carries no
  session state a repo call runs under. The scope cap is `:none`.

  The commit is the version identifier of every decision. `publish/0`
  emits it as a policy version, because a deploy of the policy directory is
  a version (`Mediate.Cerbos.Version`). What reaches the sidecar is what
  the declarations name, so a policy cannot depend on a value no one
  declared. The moment the request carries, and each request-time fact an
  `environment` block declares, go as one principal attribute beside the
  subject's own.
  """

  @behaviour Mediate.Adapter

  use Boundary,
    deps: [Mediate, Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [
      Attribute,
      Attributes,
      Binding,
      Client,
      Coverage,
      Propagation,
      Request,
      Version
    ]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Infrastructure.Decide
  alias Mediate.Cerbos.Infrastructure.Version
  alias Mediate.Error
  alias Mediate.PolicyVersion

  @schema NimbleOptions.new!(
            address: [
              type: :string,
              required: true,
              doc: "The host and port the sidecar answers on, such as `127.0.0.1:3592`."
            ]
          )

  @doc "Emits the bound directory's commit as a policy version. `Mediate.Cerbos.Version` says what it holds."
  @spec publish() :: {:ok, PolicyVersion.t()} | {:error, Error.t()}
  def publish, do: Version.publish(__MODULE__)

  @impl Mediate.Adapter
  def options_schema, do: @schema

  @impl Mediate.Adapter
  def scope_cap, do: :none

  @impl Mediate.Adapter
  def decide({_kind, _account} = subject, operation, {_type, _id} = object, %{now: _now} = environment, options)
      when is_atom(operation) do
    with {:ok, binding, address} <- bound(:decide, options) do
      named(Decide.one(binding, address, subject, operation, object, environment), :decide)
    end
  end

  @impl Mediate.Adapter
  def scope({_kind, _account} = subject, operation, object_type, %{now: _now} = environment, options)
      when is_atom(operation) and is_atom(object_type) do
    with {:ok, binding, address} <- bound(:scope, options) do
      named(Decide.scoped(binding, address, subject, operation, object_type, environment), :scope)
    end
  end

  defp named({:error, detail}, callback) when is_binary(detail) do
    {:error, engine(callback, detail)}
  end

  defp named(other, _callback), do: other

  defp bound(operation, options) do
    with {:ok, address} <- address(operation, options),
         {:ok, %Binding{} = binding} <- resolved(operation) do
      {:ok, binding, address}
    end
  end

  defp resolved(operation) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, detail: detail}} -> {:error, engine(operation, detail)}
    end
  end

  defp address(operation, options) do
    case Keyword.fetch(options, :address) do
      {:ok, address} when is_binary(address) -> {:ok, address}
      _absent -> {:error, engine(operation, "the configuration entry names no address for the sidecar")}
    end
  end

  defp engine(operation, detail) do
    %Error{reason: :engine_unreachable, detail: "#{inspect(__MODULE__)} failed during #{operation}: #{detail}"}
  end
end
