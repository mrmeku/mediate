defmodule Mediate.Cerbos do
  @moduledoc """
  Cerbos: the engine whose rules are policy files a Cerbos server reads.

  The configuration boots with `engine: {Mediate.Cerbos, address: "127.0.0.1:3592"}`
  (`Mediate.Config`). The entry carries the server's `address:` and
  nothing else, because the address is where the process runs. The rest
  comes from the binding `Mediate.Cerbos.Binding.bind/1` makes at boot:
  the mediated repo, the declarations, the policy directory, and the
  commit of that directory.

  Every call reads the declared attribute values through the bound repo,
  then asks the server once. `authorize` asks for a decision over the row
  the resource names, and the verdict names the policy the server
  evaluated. `filter` asks for a plan over the resource type and compiles
  it into a `dynamic`. A plan the compiler refuses fails `filter` with the
  sentence that says why, and the library answers the call as a denial.
  The filter limit is `:infinity`.

  The engine has no `around_query/3`, because the server carries no
  session state a repo call runs under. The commit is the policy version
  of every verdict, and `release/0` publishes it, because a deploy of the
  policy directory is a release (`Mediate.Cerbos.Version`). What reaches
  the server is what the declarations name, so a policy cannot read a
  value no one declared. The context facts go as one principal attribute
  beside the subject's own (`Mediate.Cerbos.Declarations`).
  """

  @behaviour Mediate.Engine

  use Boundary,
    deps: [Mediate, Ecto, NimbleOptions],
    check: [apps: [:ecto_sql, :postgrex]],
    exports: [Attribute, Binding, Client, Declarations, Facts, Request, Version]

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Infrastructure.Decide
  alias Mediate.Cerbos.Infrastructure.Release
  alias Mediate.Error
  alias Mediate.PolicyRelease

  @schema NimbleOptions.new!(
            address: [
              type: :string,
              required: true,
              doc: "The host and port the server answers on, such as `127.0.0.1:3592`."
            ]
          )

  @doc "Builds the bound directory's release and publishes it. `Mediate.Cerbos.Version` says what the release holds."
  @spec release() :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def release, do: Release.publish(__MODULE__)

  @impl Mediate.Engine
  def options_schema, do: @schema

  @impl Mediate.Engine
  def filter_limit, do: :infinity

  @impl Mediate.Engine
  def authorize({_kind, _account} = subject, action, {_type, _id} = resource, %{now: _now} = context, options)
      when is_atom(action) do
    with {:ok, binding, address} <- bound(:authorize, options) do
      failed(Decide.one(binding, address, subject, action, resource, context), :authorize)
    end
  end

  @impl Mediate.Engine
  def filter({_kind, _account} = subject, action, resource_type, %{now: _now} = context, options)
      when is_atom(action) and is_atom(resource_type) do
    with {:ok, binding, address} <- bound(:filter, options) do
      failed(Decide.filter(binding, address, subject, action, resource_type, context), :filter)
    end
  end

  defp failed({:error, text}, callback) when is_binary(text) do
    {:error, %Error{reason: :engine_failed, message: "#{inspect(__MODULE__)} failed during #{callback}: #{text}"}}
  end

  defp failed(other, _callback), do: other

  defp bound(callback, options) do
    with {:ok, address} <- address(callback, options),
         {:ok, %Binding{} = binding} <- resolved(callback) do
      {:ok, binding, address}
    end
  end

  defp resolved(callback) do
    case Binding.resolve() do
      {:ok, %Binding{} = binding} -> {:ok, binding}
      {:error, %Error{reason: :invalid, message: message}} -> failed({:error, message}, callback)
    end
  end

  defp address(callback, options) do
    case Keyword.fetch(options, :address) do
      {:ok, address} when is_binary(address) ->
        {:ok, address}

      _absent ->
        entry = inspect({__MODULE__, options})
        failed({:error, "invalid engine: #{entry} names no address; add address: \"host:port\""}, callback)
    end
  end
end
