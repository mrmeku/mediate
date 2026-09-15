defmodule Mediate.Fga.MixProject do
  use Mix.Project

  def project do
    [
      app: :mediate_fga,
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

  # `:inets` carries `httpc`, which `Mediate.Fga.Client.Http` asks the
  # server with. The package that calls it starts it, so an adopter of this
  # package does not have to know its transport.
  def application do
    [extra_applications: [:logger, :inets]]
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
      [summary: [threshold: 90]]
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # ecto_sql carries no `only:` because the migration helpers ship in lib.
  # postgrex carries no `only:` because the relay's cursor and lock are
  # Postgres, so an application that runs the drain runs it on Postgres.
  # stream_data carries no `only:` because this package's own case templates
  # ship in lib. telemetry carries no `only:` because the real client emits one
  # event per call from lib.
  #
  # muontrap serves the test run alone, where it
  # starts the one server the suite asks for. Every pin is exact. Versions
  # verified against https://hex.pm/api/packages/<name> on 2026-09-09.
  defp deps do
    [
      {:mediate, in_umbrella: true},
      {:mediate_dev, in_umbrella: true, only: :test},
      {:ecto, "3.14.2"},
      {:ecto_sql, "3.14.0"},
      {:nimble_options, "1.1.1"},
      {:postgrex, "0.22.4"},
      {:stream_data, "1.4.0"},
      {:telemetry, "1.4.2"},
      {:muontrap, "2.0.0", only: :test},
      {:boundary, "0.10.4", runtime: false},
      {:credo, "1.7.19", only: [:dev, :test], runtime: false},
      {:mediate_credo, in_umbrella: true, only: [:dev, :test], runtime: false},
      {:styler, "1.12.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.40.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "2.1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md": [title: "Mediate FGA"]]]
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
