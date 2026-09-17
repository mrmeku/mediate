defmodule Mediate.Conformance.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mrmeku/mediate"

  def project do
    [
      app: :mediate_conformance,
      version: @version,
      description: "The suites that hold a Mediate adapter and a mediated repo to the conformance laws.",
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
      test_coverage: [summary: [threshold: 90]],
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

  # The templates ship in lib, so an adopter's suite draws a population from
  # them. stream_data carries no `only:` for that reason, and telemetry is
  # here because the audit laws attach a handler. ecto_sql and postgrex
  # serve this package's own run of the repo template. Each published
  # requirement is compatible rather than exact, so an adopter already on a
  # later patch can install this package, and mix.lock holds the version and
  # the checksum this repository builds against. Versions verified against
  # https://hex.pm/api/packages/<name> on 2026-09-08.
  defp deps do
    [
      {:mediate, sibling("~> 0.1")},
      {:mediate_dev, in_umbrella: true, only: :test},
      {:ecto, "~> 3.14"},
      {:telemetry, "~> 1.4"},
      {:stream_data, "~> 1.4"},
      {:ecto_sql, "~> 3.14", only: :test},
      {:postgrex, "~> 0.22", only: :test},
      {:boundary, "~> 0.10", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mediate_credo, in_umbrella: true, only: [:dev, :test], runtime: false},
      {:styler, "1.12.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.40.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "2.1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp sibling(requirement) do
    if System.get_env("MEDIATE_UMBRELLA"), do: [in_umbrella: true], else: requirement
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md": [title: "Mediate conformance"]]
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
