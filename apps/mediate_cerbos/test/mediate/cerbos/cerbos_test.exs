defmodule Mediate.CerbosTest do
  use ExUnit.Case, async: true

  alias Mediate.Cerbos.Binding
  alias Mediate.Cerbos.Conformance.Reference
  alias Mediate.Cerbos.Conformance.Server
  alias Mediate.Dev
  alias Mediate.Error
  alias Mediate.Fixture.Folder
  alias Mediate.TestRepos.Sandboxed
  alias Mediate.Verdict

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
              - expr: request.principal.attr.context.reauthenticated_at != null
              - expr: >
                  timestamp(request.principal.attr.context.now) -
                  timestamp(request.principal.attr.context.reauthenticated_at) < duration("900s")
|

  defmodule Window do
    @moduledoc false
    use Mediate.Cerbos.Declarations

    alias Mediate.Fixture.Account

    principal :user, schema: Account do
    end

    resource :folder, schema: Folder do
    end

    context do
      fact(:reauthenticated_at)
    end
  end

  setup do
    server = Dev.Cerbos.current!()

    :ok =
      Binding.override(repo: Sandboxed, declarations: Reference, policy_dir: server.policy_dir, commit: "conformance")

    {:ok, address: server.http, context: %{now: DateTime.utc_now()}}
  end

  test "the engine has no filter limit, and its entry carries the address alone" do
    assert Mediate.Cerbos.filter_limit() == :infinity
    assert Mediate.Cerbos.options_schema().schema[:address][:required]
    assert Keyword.keys(Mediate.Cerbos.options_schema().schema) == [:address]
  end

  test "an entry with no address is an engine error naming the callback that failed", ctx do
    for {callback, call} <- callbacks(ctx, []) do
      assert {:error, %Error{reason: :engine_failed} = error} = call.()

      assert error.message ==
               "Mediate.Cerbos failed during #{callback}: invalid engine: {Mediate.Cerbos, []} names no address; " <>
                 "add address: \"host:port\""
    end
  end

  test "a binding that does not resolve is an engine error naming the callback that failed", ctx do
    :ok = Binding.override(declarations: Folder)

    for {callback, call} <- callbacks(ctx, address: ctx.address) do
      assert {:error, %Error{reason: :engine_failed} = error} = call.()

      assert error.message ==
               "Mediate.Cerbos failed during #{callback}: invalid binding: " <>
                 "Mediate.Fixture.Folder did not use Mediate.Cerbos.Declarations; " <>
                 "add use Mediate.Cerbos.Declarations or bind the module that does"
    end
  end

  test "a policy that reads a context fact is answered from the moment the request carries" do
    server = Server.start!([{"folder.yaml", @window}])
    :ok = Binding.override(repo: Sandboxed, declarations: Window, policy_dir: server.policy_dir, commit: "window")
    now = ~U[2026-09-09 12:00:00Z]
    options = [address: server.http]

    fresh = %{now: now, reauthenticated_at: DateTime.shift(now, minute: -1)}
    assert {:ok, %Verdict{effect: :allow}} = Mediate.Cerbos.authorize(@ann, :read, @folder, fresh, options)

    stale = %{now: now, reauthenticated_at: DateTime.shift(now, second: -901)}
    assert {:ok, %Verdict{effect: :deny}} = Mediate.Cerbos.authorize(@ann, :read, @folder, stale, options)

    absent = %{now: now}
    assert {:ok, %Verdict{effect: :deny}} = Mediate.Cerbos.authorize(@ann, :read, @folder, absent, options)
  end

  defp callbacks(ctx, options) do
    [
      {:authorize, fn -> Mediate.Cerbos.authorize(@ann, :read, @folder, ctx.context, options) end},
      {:filter, fn -> Mediate.Cerbos.filter(@ann, :read, :folder, ctx.context, options) end}
    ]
  end
end
