defmodule ExampleRbac.MixProject do
  use Mix.Project

  def project do
    [
      app: :example_rbac,
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
      test_coverage: [summary: [threshold: 90]],
      aliases: aliases(),
      hex: hex(),
      deps: deps(),
      docs: docs(),
      mediate: mediate()
    ]
  end

  # The dump task raises an ephemeral cluster, and the connection library
  # under the cluster loads in the test environment alone.
  def cli do
    [preferred_envs: [quality: :test, "mediate.schema_dump": :test]]
  end

  def application do
    [mod: {ExampleRbac.Application, []}, extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # What the library's tasks read. The migrations of this repo produce the
  # committed schema file. The repo's own configuration lives under its
  # otp_app.
  defp mediate do
    [
      schema_dump: [repo: Example.Infrastructure.OwnerRepo, output: "priv/schema/rbac.sql"]
    ]
  end

  # The example, the adapter, and the connection library under the cluster
  # the dump task raises. Every pin is exact. Versions verified against
  # https://hex.pm/api/packages/<name> on 2026-09-08.
  defp deps do
    [
      {:mediate, sibling(:mediate)},
      {:mediate_dev, in_umbrella: true, only: :test},
      {:example, in_umbrella: true},
      {:mediate_rbac, sibling(:mediate_rbac)},
      {:ecto, "3.14.2"},
      {:ecto_sql, "3.14.0"},
      {:postgrex, "0.22.4"},
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
    [main: "readme", extras: ["README.md": [title: "The example under RBAC in code"]]]
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
