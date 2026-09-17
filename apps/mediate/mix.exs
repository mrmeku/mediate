defmodule Mediate.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mrmeku/mediate"

  def project do
    [
      app: :mediate,
      version: @version,
      description:
        "The authorization port an Elixir application calls, with the mediated Ecto repo, the events, and the adapter behaviour.",
      package: package(),
      source_url: @source_url,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.20.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true, infer_signatures: true, no_warn_undefined: []],
      compilers: [:boundary] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      test_coverage: test_coverage(),
      aliases: aliases(),
      hex: hex(),
      deps: deps(),
      docs: docs()
    ]
  end

  def cli do
    [preferred_envs: [quality: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # The coverage a run measures. A run with MEDIATE_DOMAIN_COVERAGE set
  # ignores every module outside a `domain/` and holds the rest to every
  # line. A module that decides and touches nothing can meet that. Any
  # other run is the ordinary one, and its threshold is a floor under the
  # application as a whole.
  defp test_coverage do
    if System.get_env("MEDIATE_DOMAIN_COVERAGE") do
      [summary: [threshold: 100], ignore_modules: [~r/^(?!.*\.Domain\.)/]]
    else
      [summary: [threshold: 90], ignore_modules: ignore_modules()]
    end
  end

  defp ignore_modules, do: [~r/TestRepos\./]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Design" => "https://hexdocs.pm/mediate/design.html"
      }
    ]
  end

  # `ecto_sql` is optional, because an application that takes the port
  # without the seam needs `ecto` alone.
  #
  # `postgrex` is the driver this package's own suite connects with, and
  # `stream_data` draws the population one property of that suite asks for.
  # The schemas the suite proves the package over sit in `test/support`,
  # which the compiler sees and Hex never publishes. The cluster and
  # the sandbox setup come from `mediate_dev`, in the test environment
  # alone. The conformance templates are `mediate_conformance`, which
  # depends on this package and which this package cannot name back.
  # Each published requirement is compatible rather than exact, so an
  # adopter already on a later patch can install this package, and mix.lock
  # holds the version and the checksum this repository builds against.
  # Versions verified against https://hex.pm/api/packages/<name> on
  # 2026-09-08.
  defp deps do
    [
      {:mediate_dev, in_umbrella: true, only: :test},
      {:ecto, "~> 3.14"},
      {:nimble_options, "~> 1.1"},
      {:telemetry, "~> 1.4"},
      {:ecto_sql, "~> 3.14", optional: true},
      {:postgrex, "~> 0.22", only: :test},
      {:stream_data, "~> 1.4", only: :test},
      {:boundary, "~> 0.10", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mediate_credo, in_umbrella: true, only: [:dev, :test], runtime: false},
      {:styler, "1.12.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.40.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "2.1.5", only: [:dev, :test], runtime: false}
    ]
  end

  # This package is the canonical home of the six documents the umbrella
  # shares, so HexDocs holds one copy of each and every other package links
  # to it. ExDoc reads an extra relative to the working directory, `filename`
  # names the page, and `source` names the path the view-source link points
  # at.
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md": [title: "Mediate core"],
        "../../docs/design.md": [title: "Design", filename: "design", source: "docs/design.md"],
        "../../docs/controls.md": [
          title: "Controls",
          filename: "controls",
          source: "docs/controls.md"
        ],
        "../../docs/conformance.md": [
          title: "Conformance",
          filename: "conformance",
          source: "docs/conformance.md"
        ],
        "../../docs/events.md": [title: "Events", filename: "events", source: "docs/events.md"],
        "../../docs/example.md": [
          title: "The example",
          filename: "example",
          source: "docs/example.md"
        ],
        "../../docs/writing.md": [
          title: "Writing",
          filename: "writing",
          source: "docs/writing.md"
        ]
      ]
    ]
  end

  # CVE-2026-32686 (GHSA-rhv4-8758-jx7v): an unbounded exponent when decimal
  # parses an untrusted string. Every decimal release is in the advisory's
  # range, and no release has a patch. Checked at
  # https://api.osv.dev/v1/vulns/EEF-CVE-2026-32686 and
  # https://hex.pm/api/packages/decimal on 2026-09-08. Mediate parses no
  # decimal and declares no decimal field. So this file acknowledges the
  # advisory and does not fix it. Review it when a patched release appears.
  defp hex do
    [ignore_advisories: ["CVE-2026-32686"]]
  end

  defp aliases do
    [
      quality: [
        # First, because Hex requires it before any task that loads the application.
        "hex.audit",
        "format --check-formatted",
        "compile --force --warnings-as-errors --all-warnings",
        "credo --strict --all",
        "xref graph --label compile-connected --fail-above 0",
        "xref graph --format cycles --fail-above 0",
        "deps.audit --ignore-advisory-ids GHSA-rhv4-8758-jx7v",
        "docs --warnings-as-errors",
        "test --warnings-as-errors --cover"
      ]
    ]
  end
end
