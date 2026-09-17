defmodule Mix.Tasks.Mediate.Package do
  @shortdoc "Builds the deployable of every published package, and checks what each one carries"
  @moduledoc """
  Builds the tarball of every package this repository publishes, with
  `MEDIATE_UMBRELLA` removed, and unpacks it under `tmp/package/`.

      mix mediate.package
      mix mediate.package --check

  With `--check` the task reads `hex_metadata.config` out of each unpacked
  tarball and fails on anything that would reach Hex wrong: a sibling the
  package names in production and does not require, a requirement pinned to
  an exact version, a missing license, description, or link, a LICENSE that
  is not the one at the repository root, and a version that differs across
  the set.

  The unpacked packages are what the example applications run against:

      mix mediate.package
      cd apps/example_rbac && MEDIATE_PACKAGES=../../tmp/package \\
        MIX_BUILD_ROOT=../../tmp/package/_build mix test

  `mix hex.build` fetches nothing and contacts nothing, so the whole run
  works offline and before the first release. The task runs at the umbrella
  root and takes no argument besides `--check`.
  """

  use Boundary, top_level?: true, deps: [Mix, Mediate.Dev.Package]
  use Mix.Task

  alias Mediate.Dev.Package

  @output "tmp/package"

  @impl Mix.Task
  def run(args) do
    check? = parse(args)
    root = root()

    built = Package.build(root, Path.join(root, @output))
    Enum.each(Package.published(), &Mix.shell().info("built #{&1} in #{built[&1]}"))

    if check?, do: report(Package.check(root, built))
  end

  defp parse(["--check"]), do: true
  defp parse([]), do: false
  defp parse(_args), do: Mix.raise("mix mediate.package takes --check or no argument")

  defp root do
    if Mix.Project.umbrella?() do
      File.cwd!()
    else
      Mix.raise("mix mediate.package runs at the umbrella root")
    end
  end

  defp report([]), do: Mix.shell().info("every published package carries what Hex needs")

  defp report(violations) do
    Mix.raise("the built packages would reach Hex wrong:\n" <> Enum.map_join(violations, "\n", &("  " <> &1)))
  end
end
