defmodule Mediate.PolicyRelease do
  @moduledoc """
  One released version of an engine's policy. `text` holds the policy by
  value when it is under the configured cap. Otherwise `text_location`
  names where the text lives. A decision record carries only the version.

  An engine publishes one `[:mediate, :policy, :release]` event when it
  deploys a version, through `publish/1`. [Events](events.html) under
  "Policy release" has the payload.
  """

  @event [:mediate, :policy, :release]

  @enforce_keys [:engine, :policy_version, :text_hash, :author, :approval, :released_at]
  defstruct [:engine, :policy_version, :text_hash, :author, :approval, :released_at, text: nil, text_location: nil]

  @typedoc "The version a decision record carries: a commit, a migration number, or a model id."
  @type policy_version :: String.t()

  @typedoc "One released version, as the policy release event carries it."
  @type t :: %__MODULE__{
          engine: module(),
          policy_version: policy_version(),
          text_hash: String.t(),
          text: String.t() | nil,
          text_location: String.t() | nil,
          author: String.t(),
          approval: String.t(),
          released_at: DateTime.t()
        }

  @doc "The telemetry event a release publishes, which is what a consumer attaches to."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "Publish one release. The payload is `%{release: release}`, and the measurements are empty."
  @spec publish(t()) :: :ok
  def publish(%__MODULE__{} = release), do: :telemetry.execute(@event, %{}, %{release: release})
end
