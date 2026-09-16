defmodule Example.Scenarios do
  @moduledoc """
  Every scenario of the table in `docs/example.md` under "The scenarios", declared once here.
  `use Example.Scenarios` defines them in a thin application's test module.
  The adapter comes from the thin application's boot configuration, not from
  the test.

  Each scenario's body is a function in a module under this one, named by
  the scenario's id. The scenario that measures latency, `rev-01`, runs on
  the committed database in a nested module that is not async. Every other
  scenario runs in a sandbox transaction. The last test counts: the
  scenarios defined are the table's rows, every one of them.

  A thin application whose engine keeps state of its own passes `setup:`. It
  names a module whose `setup/1` puts in place what each test needs. The
  template calls it with the test's tags after the connection is there and
  the tables are empty.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Example,
      Example.Fixture,
      Example.Scenarios.Enforcement,
      Example.Scenarios.Identity,
      Example.Scenarios.Privilege,
      Example.Scenarios.Review,
      Example.Scenarios.Revocation,
      Ecto.Adapters.SQL,
      ExUnit,
      Mediate.Dev.Sandbox
    ]

  import ExUnit.Assertions

  alias Ecto.Adapters.SQL.Sandbox
  alias Example.Infrastructure.OwnerRepo
  alias Example.Infrastructure.Repo
  alias Example.Scenarios.Row
  alias Example.Scenarios.Table

  @bodies [
    Example.Scenarios.Enforcement,
    Example.Scenarios.Privilege,
    Example.Scenarios.Revocation,
    Example.Scenarios.Review,
    Example.Scenarios.Identity
  ]

  @committed ~w[rev-01]

  @doc false
  defmacro __using__(opts) do
    setup = Keyword.get(opts, :setup)
    {committed, sandboxed} = Enum.split_with(Table.all(), &(&1.id in @committed))

    quote do
      use Example.Scenarios.Case, async: true

      setup tags do
        Example.Scenarios.setup(tags, unquote(setup))
      end

      unquote_splicing(Enum.map(sandboxed, &declare/1))

      defmodule Committed do
        @moduledoc false
        use Example.Scenarios.Case, async: false

        setup tags do
          Example.Scenarios.setup(tags, unquote(setup))
        end

        unquote_splicing(Enum.map(committed, &declare(&1, [:committed])))
      end

      test "the scenarios defined are the table's rows, every one of them" do
        Example.Scenarios.count!([__MODULE__, __MODULE__.Committed])
      end
    end
  end

  @doc """
  The per-test setup. An async scenario gets a sandbox connection. A
  committed one gets a real connection to the same repo, a truncation
  through the owner repo before the test, and another when it ends. The
  `setup:` module, where the thin application passed one, runs last.
  """
  @spec setup(map(), module() | nil) :: :ok
  def setup(tags, prepare) when is_map(tags) and is_atom(prepare) do
    if tags[:committed] do
      :ok = Sandbox.checkout(Repo, sandbox: false)
      :ok = Example.Fixture.truncate!(OwnerRepo)
      :ok = prepared(prepare, tags)
      ExUnit.Callbacks.on_exit(fn -> Example.Fixture.truncate!(OwnerRepo) end)
      :ok
    else
      :ok = Mediate.Dev.Sandbox.setup(Repo, tags)
      prepared(prepare, tags)
    end
  end

  @doc "The count test's body: see the module documentation."
  @spec count!([module()]) :: :ok
  def count!(modules) when is_list(modules) do
    declared = declared(modules)
    assert Enum.sort(declared) == Enum.sort(Table.ids())
    assert length(declared) == Table.count()
    :ok
  end

  defp prepared(nil, _tags), do: :ok
  defp prepared(prepare, tags), do: prepare.setup(tags)

  defp declare(%Row{id: id, sentence: sentence, tests: [rule | _rest]}, tags \\ []) do
    {module, function} = body(id)

    quote do
      unquote_splicing(Enum.map(tags, &quote(do: @tag(unquote(&1)))))

      scenario unquote(id), unquote(sentence), rule: unquote(rule) do
        unquote(module).unquote(function)()
      end
    end
  end

  defp declared(modules) do
    for module <- modules, %ExUnit.Test{tags: %{scenario: id}} <- module.__ex_unit__().tests, do: id
  end

  defp body(id) do
    function = String.replace(id, "-", "_")
    Enum.find_value(@bodies, &defined_in(&1, function)) || raise ArgumentError, "no body for scenario #{id}"
  end

  defp defined_in(module, function) do
    Enum.find_value(module.__info__(:functions), fn {name, arity} ->
      if arity == 0 and Atom.to_string(name) == function, do: {module, name}
    end)
  end
end
