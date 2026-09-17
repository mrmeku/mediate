defmodule Mediate.Dev.Package do
  @moduledoc """
  The mechanism behind `mix mediate.package`. It builds the deployable of
  every package this repository publishes, and reads back what each tarball
  carries.

  `mix hex.build` reads the project configuration and fetches nothing, so
  the build works offline and before the first release. Each build runs in
  an operating-system process of its own with `MEDIATE_UMBRELLA` removed,
  which is the state a release runs in. So a package binds its siblings by
  requirement here, as it will on Hex, and not by path.

  `check/2` reads `hex_metadata.config` out of the unpacked tarball and not
  the output of the build. A tarball that omits a requirement still exits 0,
  so what the artifact contains is the thing to assert.

  `published/0` is the frozen list of packages this repository publishes.
  The structure test reads it.
  """

  use Boundary, top_level?: true, deps: [Mix]

  @published ~w(
    mediate
    mediate_conformance
    mediate_credo
    mediate_rbac
    mediate_postgres
    mediate_cerbos
    mediate_fga
  )a

  @doc "The packages this repository publishes, in the order a release publishes them."
  @spec published() :: [atom()]
  def published, do: @published

  @doc """
  Builds each published package under `output`. Returns the directory of each
  unpacked tarball, by application. Writes the tarball itself under
  `output/tarballs`.
  """
  @spec build(Path.t(), Path.t()) :: %{atom() => Path.t()}
  def build(root, output) do
    Map.new(@published, &{&1, build_one(root, output, &1)})
  end

  @doc """
  Reads the metadata of each built package and returns one sentence for each
  thing that would reach Hex wrong. An empty list is a package set that is
  ready to publish.
  """
  @spec check(Path.t(), %{atom() => Path.t()}) :: [String.t()]
  def check(root, built) do
    license = File.read!(Path.join(root, "LICENSE"))
    metadata = Map.new(built, fn {app, dir} -> {app, {dir, metadata(dir)}} end)

    Enum.flat_map(@published, &violations(root, &1, metadata[&1], license)) ++ versions(metadata)
  end

  defp build_one(root, output, app) do
    directory = Path.join(output, to_string(app))
    File.rm_rf!(directory)
    hex_build!(root, app, ["--unpack", "-o", directory])

    version = metadata(directory)["version"]
    tarball = Path.join([output, "tarballs", "#{app}-#{version}.tar"])
    File.mkdir_p!(Path.dirname(tarball))
    hex_build!(root, app, ["-o", tarball])

    directory
  end

  # The release runs with no MEDIATE_UMBRELLA in its environment, so the
  # build runs that way too. `env: [{"MEDIATE_UMBRELLA", nil}]` removes the
  # variable from the child rather than emptying it.
  defp hex_build!(root, app, args) do
    directory = Path.join([root, "apps", to_string(app)])

    case System.cmd("mix", ["hex.build" | args],
           cd: directory,
           env: [{"MEDIATE_UMBRELLA", nil}],
           stderr_to_stdout: true
         ) do
      {output, 0} -> output
      {output, status} -> raise "mix hex.build in #{directory} exited with #{status}: #{output}"
    end
  end

  defp violations(root, app, {directory, metadata}, license) do
    requirements = Map.get(metadata, "requirements", [])

    missing_siblings(root, app, requirements) ++
      exact_requirements(app, requirements) ++
      package_metadata(app, metadata) ++
      license_file(app, directory, metadata, license)
  end

  # Every umbrella application the package names in production has to appear
  # as a requirement. Hex moves an `in_umbrella: true` dependency to the
  # excluded list and prints a warning, so a package built the wrong way
  # names none of its siblings and still exits 0.
  defp missing_siblings(root, app, requirements) do
    named = Enum.map(requirements, &property(&1, "name"))

    for sibling <- production_siblings(root, app), sibling not in named do
      "#{app} names the sibling #{sibling} in production, and its requirements do not"
    end
  end

  defp exact_requirements(app, requirements) do
    for requirement <- requirements,
        name = property(requirement, "name"),
        version = property(requirement, "requirement"),
        match?({:ok, _version}, Version.parse(version)) do
      "#{app} requires #{name} at the exact version #{version}, which an adopter on a later patch cannot install"
    end
  end

  defp package_metadata(app, metadata) do
    licenses = Map.get(metadata, "licenses")
    description = Map.get(metadata, "description")
    links = Map.get(metadata, "links")

    [
      {licenses == ["Apache-2.0"], "#{app} declares licenses #{inspect(licenses)} rather than [\"Apache-2.0\"]"},
      {is_binary(description) and description != "", "#{app} declares no description"},
      {is_list(links) and links != [], "#{app} declares no links"}
    ]
    |> Enum.reject(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp license_file(app, directory, metadata, license) do
    files = Map.get(metadata, "files", [])
    path = Path.join(directory, "LICENSE")

    cond do
      "LICENSE" not in files -> ["#{app} carries no LICENSE in its file list"]
      File.read!(path) != license -> ["#{app} carries a LICENSE that is not the one at the repository root"]
      true -> []
    end
  end

  defp versions(metadata) do
    versions = Map.new(metadata, fn {app, {_directory, fields}} -> {app, Map.get(fields, "version")} end)

    distinct =
      versions
      |> Map.values()
      |> Enum.uniq()

    case distinct do
      [_one] -> []
      _many -> ["the published packages carry more than one version: #{inspect(versions)}"]
    end
  end

  # What the application names when this repository reads its own `mix.exs`,
  # which is the umbrella binding. A sibling is an application of this
  # umbrella, and production is a dependency with no `only:` that keeps it
  # out of a release.
  defp production_siblings(root, app) do
    directory = Path.join([root, "apps", to_string(app)])
    deps = Mix.Project.in_project(app, directory, fn _module -> Mix.Project.config()[:deps] end)
    siblings = umbrella_apps(root)

    for dep <- deps, {name, opts} = dependency(dep), to_string(name) in siblings, production?(opts), do: to_string(name)
  end

  # The name of each application, read from the directory rather than from
  # an atom, because a package this repository never compiled has none.
  defp umbrella_apps(root) do
    root
    |> Path.join("apps/*/mix.exs")
    |> Path.wildcard()
    |> Enum.map(&app_name/1)
  end

  defp app_name(mix_exs) do
    mix_exs
    |> Path.dirname()
    |> Path.basename()
  end

  defp dependency({name, requirement}) when is_binary(requirement), do: {name, []}
  defp dependency({name, opts}) when is_list(opts), do: {name, opts}
  defp dependency({name, _requirement, opts}), do: {name, opts}

  defp production?(opts) do
    case Keyword.get(opts, :only) do
      nil -> true
      only -> :prod in List.wrap(only)
    end
  end

  defp metadata(directory) do
    path = Path.join(directory, "hex_metadata.config")
    {:ok, terms} = :file.consult(String.to_charlist(path))
    Map.new(terms)
  end

  defp property(requirement, key) do
    Enum.find_value(requirement, fn {name, value} -> if name == key, do: value end)
  end
end
