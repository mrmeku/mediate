defmodule Mediate.Cerbos.Version do
  @moduledoc """
  The policy version of policy files: the commit of the repository they
  are in, which the binding names.
  [the events document](https://hexdocs.pm/mediate/events.html) under
  "Policy release" has the event and what it carries.

  The version is not a digest of the files, and it is not the `version`
  field inside a policy. That field runs variants of a policy side by
  side. So two variants are in force at once, and neither is the history
  of the other. History is what the repository holds. A server that reads
  a directory has no opinion about history either, so the deployment
  states the commit it serves.

  The text is the policy files, each preceded by its path. The text hash
  is the sha256 of that text, under the cap or not. So a directory that
  changed without a new commit shows as a hash that no longer matches. The
  release carries the text by value when under the configured cap, and
  the directory and the commit as its location otherwise.

  `Mediate.Cerbos.release/0` builds the release and publishes it, one
  event per call. It stores nothing, so the consumer that keeps a record
  of deployments handles that event.
  """

  alias Mediate.Cerbos.Binding
  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.PolicyRelease

  @marker "# mediate-policy: "

  @typedoc "A policy file: its path relative to the policy directory, and its text."
  @type file :: {Path.t(), String.t()}

  @doc "The policy version a verdict names: the commit the binding gives."
  @spec policy_version(Binding.t()) :: PolicyRelease.policy_version()
  def policy_version(%Binding{commit: commit}), do: commit

  @doc "The policy files of the bound directory, by path relative to it, sorted."
  @spec files(Binding.t()) :: {:ok, [file()]} | {:error, Error.t()}
  def files(%Binding{policy_dir: directory}) do
    paths =
      directory
      |> Path.join("**/*.{yaml,yml}")
      |> Path.wildcard()
      |> Enum.sort()

    step = fn path, {:ok, acc} -> read(directory, path, acc) end

    with {:ok, reversed} <- Enum.reduce_while(paths, {:ok, []}, step), do: {:ok, Enum.reverse(reversed)}
  end

  @doc "The files as one text, each preceded by its path, which `from_text/1` reads back."
  @spec text([file()]) :: String.t()
  def text(files) when is_list(files) do
    Enum.map_join(files, "", fn {path, text} -> @marker <> path <> "\n" <> ended(text) end)
  end

  @doc "The text back to the files, by path, in the order the text carries them."
  @spec from_text(String.t()) :: [file()]
  def from_text(text) when is_binary(text) do
    text
    |> String.split(@marker)
    |> Enum.flat_map(&parted/1)
  end

  @doc "The sha256 of the text, in lower-case hex."
  @spec text_hash(String.t()) :: String.t()
  def text_hash(text) when is_binary(text), do: Base.encode16(:crypto.hash(:sha256, text), case: :lower)

  @doc "The release of `engine` as the event carries it, with the text by value when under the cap."
  @spec release(module(), Binding.t(), Config.t(), DateTime.t()) :: {:ok, PolicyRelease.t()} | {:error, Error.t()}
  def release(engine, %Binding{} = binding, %Config{caps: caps}, %DateTime{} = released_at) when is_atom(engine) do
    with {:ok, files} <- files(binding) do
      text = text(files)
      under_cap? = byte_size(text) <= caps[:policy_text_bytes]

      {:ok,
       %PolicyRelease{
         engine: engine,
         policy_version: policy_version(binding),
         text_hash: text_hash(text),
         text: if(under_cap?, do: text),
         text_location: if(under_cap?, do: nil, else: location(binding)),
         author: binding.author,
         approval: binding.approval,
         released_at: released_at
       }}
    end
  end

  defp read(directory, path, acc) do
    case File.read(path) do
      {:ok, text} ->
        {:cont, {:ok, [{Path.relative_to(path, directory), text} | acc]}}

      {:error, reason} ->
        {:halt, {:error, Error.invalid(:policy_dir, "#{path} could not be read: #{:file.format_error(reason)}")}}
    end
  end

  defp parted(""), do: []

  defp parted(part) do
    case String.split(part, "\n", parts: 2) do
      [path, text] -> [{path, text}]
      [_only] -> []
    end
  end

  defp ended(text) do
    if String.ends_with?(text, "\n"), do: text, else: text <> "\n"
  end

  defp location(%Binding{policy_dir: directory, commit: commit}), do: "policy files in #{directory} at commit #{commit}"
end
