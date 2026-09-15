defmodule Mediate.CerbosTest do
  use ExUnit.Case, async: true

  alias Mediate.Answer
  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Attributes
  alias Mediate.Cerbos.Sidecar
  alias Mediate.Dev
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.TestRepos.Sandboxed

  @ann {:user, "ann"}
  @folder {:folder, 1}

  @window ~s|
apiVersion: api.cerbos.dev/v1
resourcePolicy:
  version: default
  resource: folder
  rules:
    - actions: ["read"]
      effect: EFFECT_ALLOW
      roles: ["user"]
      condition:
        match:
          all:
            of:
              - expr: request.principal.attr.environment.reauthenticated_at != null
              - expr: >
                  timestamp(request.principal.attr.environment.now) -
                  timestamp(request.principal.attr.environment.reauthenticated_at) < duration("900s")
|

  defmodule Window do
    @moduledoc false
    use Mediate.Cerbos.Attributes

    alias Mediate.Fixture.Account

    principal :user, schema: Account do
    end

    resource :folder, schema: Folder do
    end

    environment do
      fact(:reauthenticated_at)
    end
  end

  setup do
    sidecar = Dev.Cerbos.info()

    :ok =
      Binding.override(repo: Sandboxed, attributes: Attributes, policies: sidecar.policies, commit: "conformance")

    {:ok, address: sidecar.address, environment: %{now: DateTime.utc_now()}}
  end

  test "the adapter caps no scope, and its entry carries the address alone" do
    assert Mediate.Cerbos.scope_cap() == :none
    assert Mediate.Cerbos.options_schema().schema[:address][:required]
    assert Keyword.keys(Mediate.Cerbos.options_schema().schema) == [:address]
  end

  test "an entry with no address is an engine error naming the callback that failed", ctx do
    for {operation, call} <- callbacks(ctx, []) do
      assert {:error, %Error{reason: :engine_unreachable} = error} = call.()

      assert error.detail ==
               "#{inspect(Mediate.Cerbos)} failed during #{operation}: " <>
                 "the configuration entry names no address for the sidecar"
    end
  end

  test "a binding that does not resolve is an engine error naming the callback that failed", ctx do
    :ok = Binding.override(attributes: Folder)

    for {operation, call} <- callbacks(ctx, address: ctx.address) do
      assert {:error, %Error{reason: :engine_unreachable} = error} = call.()

      assert error.detail ==
               "#{inspect(Mediate.Cerbos)} failed during #{operation}: invalid binding: " <>
                 "Mediate.Fixture.Folder did not use Mediate.Cerbos.Attributes"
    end
  end

  test "a policy that reads a request-time fact is answered from the moment the request carries" do
    sidecar = Sidecar.over!([{"folder.yaml", @window}])
    :ok = Binding.override(repo: Sandboxed, attributes: Window, policies: sidecar.policies, commit: "window")
    now = ~U[2026-09-09 12:00:00Z]
    options = [address: sidecar.address]

    fresh = %{now: now, reauthenticated_at: DateTime.shift(now, minute: -1)}
    assert {:ok, %Answer{verdict: :allow}} = Mediate.Cerbos.decide(@ann, :read, @folder, fresh, options)

    stale = %{now: now, reauthenticated_at: DateTime.shift(now, second: -901)}
    assert {:ok, %Answer{verdict: :deny}} = Mediate.Cerbos.decide(@ann, :read, @folder, stale, options)

    absent = %{now: now}
    assert {:ok, %Answer{verdict: :deny}} = Mediate.Cerbos.decide(@ann, :read, @folder, absent, options)
  end

  defp callbacks(ctx, options) do
    [
      {:decide, fn -> Mediate.Cerbos.decide(@ann, :read, @folder, ctx.environment, options) end},
      {:scope, fn -> Mediate.Cerbos.scope(@ann, :read, :folder, ctx.environment, options) end}
    ]
  end
end
