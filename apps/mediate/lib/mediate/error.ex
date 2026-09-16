defmodule Mediate.Error do
  @moduledoc """
  The one exception. `reason` is the word that says why, and `detail` is the
  sentence a reader needs, which is also the message.

  A reason an answer carries is a reason an error carries, so an error that
  follows a denial names what the answer named. Three reasons belong to the
  library and not to a decider:

  - `:unsupported`, for what an adapter or a configuration cannot do
  - `:invalid`, for a value at an edge that did not validate: a bulk write
    or an upsert on an audited schema, a raw call given a decision, a bad
    option, or a configuration that did not boot
  - `:unmediated`, for a call that reached the seam with no decision and no
    exemption
  """

  alias Mediate.Answer

  @library [:unsupported, :invalid, :unmediated]

  @enforce_keys [:reason, :detail]
  defexception @enforce_keys

  @typedoc "Why the call failed. An error never carries `:allowed`."
  @type reason :: Answer.reason() | :unsupported | :invalid | :unmediated

  @type t :: %__MODULE__{reason: reason(), detail: String.t()}

  @doc "The reasons an error carries: a denial's reasons, and the library's own."
  @spec reasons() :: [reason()]
  def reasons, do: (Answer.reasons() -- [:allowed]) ++ @library

  @doc """
  The error a denial makes. It names the reason the answer gave and who
  cannot do what. It adds the decider's own text where the answer carried
  one.
  """
  @spec denied(Mediate.subject(), atom(), Mediate.object() | atom(), reason(), String.t() | nil) :: t()
  def denied({kind, account}, operation, object, reason, detail \\ nil) when is_atom(operation) do
    %__MODULE__{
      reason: reason,
      detail: "#{kind} #{account} may not #{operation} #{inspect(object)}: #{reason}#{said(detail)}"
    }
  end

  @doc "The error a value at an edge makes: what did not validate, and why it did not."
  @spec invalid(atom(), String.t()) :: t()
  def invalid(what, detail) when is_atom(what) and is_binary(detail) do
    %__MODULE__{reason: :invalid, detail: "invalid #{what}: #{detail}"}
  end

  @impl Exception
  def message(%__MODULE__{detail: detail}), do: detail

  defp said(nil), do: ""
  defp said(text), do: " (" <> text <> ")"
end
