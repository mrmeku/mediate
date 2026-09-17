defmodule Mediate.Fga.Version do
  @moduledoc """
  The policy version of this adapter: the id the server gives a model on
  its publish. A model is immutable and the server keeps it. So an id names
  one text for as long as the store lives, and a decision names that id as
  the version it ran under.
  [the events document](https://hexdocs.pm/mediate/events.html) under
  "Policy version" has what the event carries.

  The content is the model text the binding names. The version carries it
  by value under the cap, and as a pointer to the file above it. The
  content hash is the digest of that text either way. The hash is what
  tells one text from another. The text is the artifact under review, and
  a text that changed by a character is a version of its own.

  `Mediate.Fga.publish/0` writes the model and emits `telemetry_event/0`
  with the version. The adapter stores nothing. So whoever keeps a record
  of deployments handles that event. Every question carries the id
  the configuration pins, so no question runs under a model that no record
  names.
  """

  alias Mediate.Fga.Client
  alias Mediate.PolicyVersion

  @telemetry [:mediate, :fga, :policy_version]

  @doc "The telemetry event `Mediate.Fga.publish/0` emits, once per call."
  @spec telemetry_event() :: [atom()]
  def telemetry_event, do: @telemetry

  @doc "The digest of the model text."
  @spec content_hash(String.t()) :: String.t()
  def content_hash(text) when is_binary(text), do: Base.encode16(:crypto.hash(:sha256, text), case: :lower)

  @doc """
  The version an event carries for a model the server holds.
  Requires `author:`, `approval:`, `at:`, `path:`, and `content_bytes:`.
  """
  @spec of(module(), Client.model(), String.t(), keyword()) :: PolicyVersion.t()
  def of(adapter, model, text, options) when is_atom(adapter) and is_binary(model) and is_binary(text) do
    carried? = byte_size(text) <= Keyword.fetch!(options, :content_bytes)

    %PolicyVersion{
      adapter: adapter,
      version: model,
      content_hash: content_hash(text),
      content: if(carried?, do: text),
      pointer: if(carried?, do: nil, else: "the model in #{Keyword.fetch!(options, :path)}"),
      author: Keyword.fetch!(options, :author),
      approval: Keyword.fetch!(options, :approval),
      at: Keyword.fetch!(options, :at)
    }
  end
end
