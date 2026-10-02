defmodule Mediate.Cerbos.Conformance.Server do
  @moduledoc """
  A server of one test's own, over a policy directory of that test's own.

  The run's server serves the conformance policy files where they sit in
  the repository, and every test asks it at once. A test that writes a
  policy file cannot use it, because the write changes what another test
  reads, and every test owns its state. So the test gets a directory under
  `tmp/`, with a copy of the conformance policy files or with policy files
  of its own. A server on that directory stops when the test ends.
  """

  alias Mediate.Dev

  @conformance "priv/conformance"

  @doc "A server over a copy of the conformance policy files."
  @spec start!() :: Dev.Cerbos.t()
  def start! do
    started(fn directory ->
      Enum.each(files(), fn {name, text} -> File.write!(Path.join(directory, name), text) end)
    end)
  end

  @doc "A server over the policy files given, each by its path and its text."
  @spec start!([{String.t(), String.t()}]) :: Dev.Cerbos.t()
  def start!(files) when is_list(files) do
    started(fn directory -> Enum.each(files, &write!(directory, &1)) end)
  end

  @doc "The conformance policy files, by file name, in the order the directory holds them."
  @spec files() :: [{String.t(), String.t()}]
  def files do
    paths =
      @conformance
      |> Path.join("*.yaml")
      |> Path.wildcard()
      |> Enum.sort()

    for path <- paths, do: {Path.basename(path), File.read!(path)}
  end

  defp started(write) do
    directory = Path.join([File.cwd!(), "tmp", "own-" <> suffix()])
    policy_dir = Path.join(directory, "policies")
    File.mkdir_p!(policy_dir)
    write.(policy_dir)
    Dev.Cerbos.start_supervised!(policy_dir: policy_dir, dir: directory)
  end

  defp write!(directory, {path, text}) do
    full = Path.join(directory, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, text)
  end

  defp suffix, do: Base.url_encode64(:crypto.strong_rand_bytes(8), padding: false)
end
