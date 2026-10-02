defmodule Mediate.Error do
  @moduledoc """
  The one exception. `reason` is the word that says why, and `message` is
  the sentence a reader needs.

  A reason a verdict carries is a reason an error carries, so an error that
  follows a denial names what the verdict named. Three reasons belong to
  the library and not to an engine:

  - `:unsupported`, for what an engine or a configuration cannot do
  - `:invalid`, for a value at an edge that did not validate: a bulk write
    or an upsert on an identity schema, a raw call given a decision, a bad
    option, or a configuration that did not boot
  - `:decision_missing`, for a call that reached the mediated repo with no
    decision and no exemption
  """

  alias Mediate.Verdict

  @library [:unsupported, :invalid, :decision_missing]

  @enforce_keys [:reason, :message]
  defexception @enforce_keys

  @typedoc "Why the call failed. An error never carries `:rule_allowed`."
  @type reason :: Verdict.reason() | :unsupported | :invalid | :decision_missing

  @typedoc "A failed call: why, and a message that names what failed."
  @type t :: %__MODULE__{reason: reason(), message: String.t()}

  @doc "The reasons an error carries: a denial's reasons, and the library's own."
  @spec reasons() :: [reason()]
  def reasons, do: (Verdict.reasons() -- [:rule_allowed]) ++ @library

  @doc """
  The error a denial makes. It names the reason the verdict gave and who
  cannot do what. It adds the engine's own text where the verdict carried
  one.
  """
  @spec denied(Mediate.subject(), atom(), Mediate.resource() | atom(), reason(), String.t() | nil) :: t()
  def denied({kind, account}, action, resource, reason, text \\ nil) when is_atom(action) do
    %__MODULE__{
      reason: reason,
      message: "#{kind} #{account} may not #{action} #{inspect(resource)}: #{reason}#{said(text)}"
    }
  end

  @doc "The error a value at an edge makes: what did not validate, and why it did not."
  @spec invalid(atom(), String.t()) :: t()
  def invalid(what, text) when is_atom(what) and is_binary(text) do
    %__MODULE__{reason: :invalid, message: "invalid #{what}: #{text}"}
  end

  defp said(nil), do: ""
  defp said(text), do: " (" <> text <> ")"
end
