defmodule Mediate.Dev.PackageTest do
  use ExUnit.Case, async: false

  alias Mediate.Dev.Package

  @umbrella Path.expand("../../../../..", __DIR__)
  @output "tmp/package_test"

  setup do
    File.rm_rf!(@output)
    on_exit(fn -> File.rm_rf!(@output) end)
    :ok
  end

  test "a package set that carries what Hex needs raises nothing" do
    assert Package.check(@umbrella, built()) == []
  end

  test "a package that names a sibling in production and does not require it is reported" do
    built = built(mediate_rbac: %{"requirements" => []})

    assert ["mediate_rbac names the sibling mediate in production, and its requirements do not"] =
             Package.check(@umbrella, built)
  end

  test "a requirement pinned to an exact version is reported" do
    built = built(mediate: %{"requirements" => [requirement("ecto", "3.14.2")]})

    assert ["mediate requires ecto at the exact version 3.14.2" <> _rest] = Package.check(@umbrella, built)
  end

  test "a missing license, description, or link is reported" do
    built = built(mediate_credo: %{"licenses" => ["MIT"], "description" => "", "links" => []})

    assert [licenses, description, links] = Package.check(@umbrella, built)
    assert licenses == ~s(mediate_credo declares licenses ["MIT"] rather than ["Apache-2.0"])
    assert description == "mediate_credo declares no description"
    assert links == "mediate_credo declares no links"
  end

  test "a package with no LICENSE in its file list, or one that differs from the root, is reported" do
    assert ["mediate_cerbos carries no LICENSE in its file list"] =
             Package.check(@umbrella, built(mediate_cerbos: %{"files" => ["mix.exs"]}))

    built = built()
    File.write!(Path.join(built[:mediate_fga], "LICENSE"), "something else")

    assert ["mediate_fga carries a LICENSE that is not the one at the repository root"] =
             Package.check(@umbrella, built)
  end

  test "a set that carries more than one version is reported" do
    built = built(mediate_postgres: %{"version" => "0.2.0"})

    assert ["the published packages carry more than one version: " <> _rest] = Package.check(@umbrella, built)
  end

  test "the published list is the one the release publishes, with mediate first" do
    assert [:mediate | rest] = Package.published()
    assert :mediate_credo in rest
    refute :mediate_dev in Package.published()
  end

  # A package directory for each published application, with the metadata a
  # correct build writes. `overrides` replaces a field of one of them, so
  # each test names the one thing it breaks.
  defp built(overrides \\ []) do
    Map.new(Package.published(), fn app ->
      directory = Path.join(@output, to_string(app))
      File.mkdir_p!(directory)
      File.cp!(Path.join(@umbrella, "LICENSE"), Path.join(directory, "LICENSE"))
      fields = Map.merge(fields(app), Map.new(Keyword.get(overrides, app, %{})))
      File.write!(Path.join(directory, "hex_metadata.config"), terms(fields))
      {app, directory}
    end)
  end

  defp fields(app) do
    %{
      "version" => "0.1.0",
      "licenses" => ["Apache-2.0"],
      "description" => "A package of this umbrella.",
      "links" => [{"GitHub", "https://github.com/mrmeku/mediate"}],
      "files" => ["mix.exs", "LICENSE"],
      "requirements" => requirements(app)
    }
  end

  defp requirements(:mediate), do: [requirement("ecto", "~> 3.14")]
  defp requirements(:mediate_credo), do: [requirement("boundary", "~> 0.10")]
  defp requirements(_app), do: [requirement("mediate", "~> 0.1")]

  defp requirement(name, version) do
    [{"name", name}, {"app", name}, {"optional", false}, {"requirement", version}, {"repository", "hexpm"}]
  end

  # `hex_metadata.config` is Erlang terms, one per line, which `:file.consult`
  # reads back.
  defp terms(fields) do
    Enum.map_join(fields, "", fn {key, value} -> "#{:io_lib.format(~c"~p.~n", [{key, value}])}" end)
  end
end
