defmodule Mediate.Dev.SurfaceTest do
  use ExUnit.Case, async: true

  alias Mediate.Dev.Cluster
  alias Mediate.Dev.Structure
  alias Mediate.Dev.Surface
  alias Mediate.Dev.SurfaceTest.Fixture

  setup_all do
    %{surface: Surface.of(:mediate_dev)}
  end

  test "the modules are the public ones under lib, and none from test/support", %{surface: surface} do
    assert Surface in surface.modules
    assert Mix.Tasks.Mediate.Surface in surface.modules
    refute Mediate.Dev.TestRepos.Sandboxed in surface.modules
    assert surface.modules == Enum.sort(surface.modules)
  end

  test "a function carries its name, its arity, and its spec on one line", %{surface: surface} do
    assert {Surface, :of, 2, "of(atom(), keyword()) :: t()"} in surface.functions
    assert {Surface, :to_lines, 1, "to_lines(t()) :: [String.t()]"} in surface.functions
    refute Enum.any?(surface.functions, fn {_module, _name, _arity, spec} -> spec =~ "\n" end)
  end

  test "a struct's fields are listed without the underscored ones", %{surface: surface} do
    assert {Surface, [:app, :atoms, :events, :fields, :functions, :modules, :options]} in surface.fields

    refute Enum.any?(surface.fields, fn {_module, fields} ->
             Enum.any?(fields, &String.starts_with?(to_string(&1), "__"))
           end)
  end

  test "the atoms of a public type's union are listed by type", %{surface: surface} do
    assert {Cluster, :role, [:app, :owner]} in surface.atoms
    assert {Cluster, :database, [:durable, :sandboxed]} in surface.atoms
  end

  test "the option keys come from the NimbleOptions schema in the module's own body", %{surface: surface} do
    assert {Structure, [:file, :migrations, :otp_app, :repo]} in surface.options
    assert {Cluster, keys} = List.keyfind(surface.options, Cluster, 0)
    assert :role in keys and :owner in keys and :app in keys
  end

  test "this package publishes no event", %{surface: surface} do
    assert surface.events == []
  end

  # The event keys come from the source: every map literal in the function
  # that calls `:telemetry.execute/3` and in the local function the payload
  # argument calls, and the event name through the attribute that holds it.
  test "an event's keys are read from the source of the module that publishes it" do
    surface = Surface.of(:mediate_dev, modules: [compiled_fixture()])

    assert surface.events == [
             {Fixture, [:mediate, :fixture, :happened], [:count, :fixture_id, :happened_at]},
             {Fixture, [:mediate, :fixture, :undone], [:fixture_id]}
           ]

    assert surface.options == [{Fixture, [:left, :right, :side]}]
    assert "event [:mediate, :fixture, :undone] fixture_id" in Surface.to_lines(surface)
  end

  test "an application of Elixir's own loads, and its sources are not here to read" do
    assert %Surface{app: :eex, options: [], events: []} = Surface.of(:eex)
  end

  test "the modules given are read as they are, and the option validates" do
    surface = Surface.of(:mediate_dev, modules: [Structure])
    assert surface.modules == [Structure]
    assert surface.options == [{Structure, [:file, :migrations, :otp_app, :repo]}]
    assert_raise NimbleOptions.ValidationError, fn -> Surface.of(:mediate_dev, modules: :all) end
  end

  @fixture Path.expand("../../../tmp/lib/surface_fixture.ex", __DIR__)

  defp compiled_fixture do
    File.mkdir_p!(Path.dirname(@fixture))

    File.write!(@fixture, """
    defmodule Mediate.Dev.SurfaceTest.Fixture do
      @moduledoc "A module that publishes two events, for the surface test."

      @event [:mediate, :fixture, :happened]
      @sides [left: [type: :atom], right: [type: :atom]]
      @schema NimbleOptions.new!(left: [type: :atom], right: [type: :atom], side: [type: {:in, [:left, :right]}])
      @computed NimbleOptions.new!(@sides)

      def schemas, do: [@schema, @computed]

      def publish(count), do: :telemetry.execute(@event, %{count: count}, payload(count))

      def undo(id), do: :telemetry.execute([:mediate, :fixture, :undone], %{}, %{fixture_id: id})

      defp payload(count) when is_integer(count), do: %{"unit" => "rows", happened_at: count, fixture_id: 1}
    end
    """)

    [{module, _binary}] = Code.compile_file(@fixture)
    module
  end

  test "the lines read as the task prints them", %{surface: surface} do
    lines = Surface.to_lines(surface)
    assert "module Mediate.Dev.Surface" in lines
    assert "function Mediate.Dev.Surface.of/2 :: of(atom(), keyword()) :: t()" in lines
    assert "field Mediate.Dev.Surface.app" in lines
    assert "atom Mediate.Dev.Cluster.role() :owner" in lines
    assert "option Mediate.Dev.Structure file:" in lines
  end

  test "an application loaded already is read the same way" do
    assert Surface.of(:mediate_dev) == Surface.of(:mediate_dev)
  end
end
