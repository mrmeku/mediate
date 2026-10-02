defmodule Mediate.OpenFGA.Version do
  @moduledoc """
  The policy version of this engine: the id the server gives a model when
  the engine writes it. A model is immutable and the server keeps it. So
  an id names one text for as long as the store lives, and a verdict names
  that id as the version it ran under.
  [the events document](https://hexdocs.pm/mediate/events.html) under
  "Policy release" has the event and what it carries.

  The text is the model file the binding names. The release carries it by
  value under the cap, and names the file as its location above it. The
  text hash is the sha256 of that text either way. The hash is what tells
  one text from another. The text is the artifact under review, and a
  text that changed by a character is a version of its own.

  `Mediate.OpenFGA.release/0` writes the model and publishes the release,
  one event per call. The engine stores nothing, so the consumer that
  keeps a record of deployments handles that event. Every question
  carries the id the configuration pins, so no question runs under a
  model that no record names.
  """

  alias Mediate.Config
  alias Mediate.Error
  alias Mediate.OpenFGA.Binding
  alias Mediate.OpenFGA.Client
  alias Mediate.PolicyRelease

  @doc "The model text, read from the file the binding names."
  @spec text(Binding.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def text(%Binding{model_file: path}) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, Error.invalid(:binding, "#{location(path)} could not be read: #{reason(reason)}")}
    end
  end

  @doc "The sha256 of the text, in lower-case hex."
  @spec text_hash(String.t()) :: String.t()
  def text_hash(text) when is_binary(text), do: Base.encode16(:crypto.hash(:sha256, text), case: :lower)

  @doc "The release of `engine` as the event carries it, with the text by value when under the cap."
  @spec release(module(), Client.model_id(), String.t(), Binding.t(), Config.t()) :: PolicyRelease.t()
  def release(engine, model_id, text, %Binding{} = binding, %Config{} = config)
      when is_atom(engine) and is_binary(model_id) and is_binary(text) do
    under_cap? = byte_size(text) <= config.caps[:policy_text_bytes]

    %PolicyRelease{
      engine: engine,
      policy_version: model_id,
      text_hash: text_hash(text),
      text: if(under_cap?, do: text),
      text_location: if(under_cap?, do: nil, else: location(binding.model_file)),
      author: binding.author,
      approval: binding.approval,
      released_at: config.clock.()
    }
  end

  defp location(path), do: "the model file #{path}"

  defp reason(reason), do: :file.format_error(reason)
end
