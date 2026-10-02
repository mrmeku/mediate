defmodule Mediate.Cerbos.Conformance.PolicyFiles do
  @moduledoc """
  The file swap the conformance policy makes. `swap!/2` writes policy
  files over the ones in a directory and answers what was there, so
  `restore!/2` can put each back. A server that watches the directory
  reads the new file once it sees the write. `tightened/0` is the folder
  policy whose read rule admits the reader role alone.
  """

  @tightened """
  # The reference world's rule for a folder, tightened: a reader's
  # membership alone admits a read, so the granted editor is denied.
  apiVersion: api.cerbos.dev/v1
  resourcePolicy:
    version: default
    resource: folder
    rules:
      - actions: ["read"]
        effect: EFFECT_ALLOW
        roles: ["user", "service", "privileged"]
        condition:
          match:
            all:
              of:
                - expr: request.principal.attr.clearance == "cleared"
                - expr: '"reader" in request.resource.attr.member_roles'
      - actions: ["edit"]
        effect: EFFECT_ALLOW
        roles: ["user", "service", "privileged"]
        condition:
          match:
            all:
              of:
                - expr: request.principal.attr.clearance == "cleared"
                - expr: '"editor" in request.resource.attr.member_roles'
      - actions: ["share"]
        effect: EFFECT_ALLOW
        roles: ["user", "service", "privileged"]
        condition:
          match:
            all:
              of:
                - expr: request.principal.attr.clearance == "cleared"
                - expr: size(request.resource.attr.member_roles) > 1
  """

  @typedoc "A policy file by its path under the directory, and its text, or `nil` for a file that was not there."
  @type file :: {Path.t(), String.t() | nil}

  @doc "The folder policy whose read rule admits the reader role alone."
  @spec tightened() :: String.t()
  def tightened, do: @tightened

  @doc "Writes each file into the directory and answers what each path held before, for `restore!/2`."
  @spec swap!(Path.t(), [file()]) :: [file()]
  def swap!(directory, files) when is_binary(directory) and is_list(files) do
    previous = for {path, _text} <- files, do: {path, read(Path.join(directory, path))}
    Enum.each(files, &write!(directory, &1))
    previous
  end

  @doc "Puts each path back to what `swap!/2` answered: its old text, or no file at all."
  @spec restore!(Path.t(), [file()]) :: :ok
  def restore!(directory, previous) when is_binary(directory) and is_list(previous) do
    Enum.each(previous, &write!(directory, &1))
  end

  defp read(path) do
    case File.read(path) do
      {:ok, text} -> text
      {:error, :enoent} -> nil
    end
  end

  defp write!(directory, {path, nil}), do: File.rm!(Path.join(directory, path))

  defp write!(directory, {path, text}) do
    full = Path.join(directory, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, text)
  end
end
