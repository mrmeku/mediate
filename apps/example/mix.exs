defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
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

  # A library application, with no callback module and nothing started.
  # The thin applications start the repos and the consumer of the events.
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Example.Scenarios and the scenario bodies are test support. They run in
  # the suites of the thin applications, under a real adapter. This
  # application's own run holds the table to the repository and covers the
  # contexts against the fake adapter.
  defp ignore_modules do
    [~r/^Example\.Scenarios/, ~r/^Example\.Fixture/, ~r/^Example\.Cluster/]
  end

  # lib depends on the library, on ecto and ecto_sql for the migration
  # helper and preload, and on telemetry. The conformance package and
  # stream_data serve the test run, where the repo answers the guarantees
  # and the domain answers its properties. Every pin is exact. Versions
  # verified
  # against https://hex.pm/api/packages/<name> on 2026-09-08.
  defp deps do
    [
      {:mediate, sibling(:mediate)},
      {:mediate_dev, in_umbrella: true, only: :test},
      {:mediate_conformance, sibling(:mediate_conformance, only: :test)},
      {:ecto, "3.14.2"},
      {:ecto_sql, "3.14.0"},
      {:postgrex, "0.22.4"},
      {:nimble_options, "1.1.1"},
      {:telemetry, "1.4.2"},
      {:stream_data, "1.4.0", only: :test},
      {:boundary, "0.10.4", runtime: false},
      {:credo, "1.7.19", only: [:dev, :test], runtime: false},
      {:mediate_credo, sibling(:mediate_credo, only: [:dev, :test], runtime: false)},
      {:styler, "1.12.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.40.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "2.1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp sibling(app, opts \\ []) do
    case System.get_env("MEDIATE_PACKAGES") do
      nil -> Keyword.put(opts, :in_umbrella, true)
      dir -> Keyword.merge(opts, path: Path.join(dir, to_string(app)), override: true)
    end
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md": [title: "The example: code hosting"]]
    ]
  end

  # CVE-2026-32686 (GHSA-rhv4-8758-jx7v): an unbounded exponent when decimal
  # parses an untrusted string. Every decimal release is in the advisory's
  # range, and no release has a patch. Checked at
  # https://api.osv.dev/v1/vulns/EEF-CVE-2026-32686 and
  # https://hex.pm/api/packages/decimal on 2026-09-08. The example parses no
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
