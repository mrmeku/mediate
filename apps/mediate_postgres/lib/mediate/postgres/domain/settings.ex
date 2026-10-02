defmodule Mediate.Postgres.Domain.Settings do
  @moduledoc false
  # The session settings a call runs under. A call always sets four:
  # `mediate.subject_id`, `mediate.subject_kind`, `mediate.action`, and
  # `mediate.now`. Beyond those, every fact the caller supplied in the
  # context gets a setting under its own name. So an application whose
  # rules read `current_setting('mediate.reauthenticated_at', true)`
  # supplies `reauthenticated_at` as a fact, and this package never learns
  # the name. A fact under one of the four fixed names is dropped, because
  # the request's values win.
  #
  # Every value is text. A value the caller did not supply is the empty
  # string. A name the caller never supplied is unset, and
  # `current_setting(name, true)` answers `NULL` for it. Neither compares
  # equal to anything a rule allows on, so an absent fact denies.
  #
  # `to_sql/1` renders the settings as one `SELECT` over
  # `set_config(name, value, true)`: one statement, one round trip, and one
  # query in the shape counts. `hash/1` is the sha256 a filter verdict
  # carries, because under row-level security the settings are what the
  # database enforced. This module runs no statement, which is why it is
  # domain. The session holds the connection and sets them.

  @prefix "mediate."
  @fixed [:now, :subject_id, :subject_kind, :action]

  @enforce_keys [:pairs]
  defstruct @enforce_keys

  @typedoc "The setting names and their text values, in the order of the statement and the hash."
  @type t :: %__MODULE__{pairs: [{String.t(), String.t()}]}

  @doc """
  The settings for a subject, an action, and the context of the call. The
  second form takes the moment of a decision in place of the context, for
  a caller that holds a decision alone. It carries no supplied fact, so a
  rule that reads one denies.
  """
  @spec new(Mediate.subject(), atom(), Mediate.context() | DateTime.t()) :: t()
  def new({kind, id}, action, %{now: now} = context) when is_atom(action) do
    fixed = [{"subject_id", id}, {"subject_kind", kind}, {"action", action}, {"now", now}]
    %__MODULE__{pairs: Enum.map(fixed ++ supplied(context), &pair/1)}
  end

  def new({_kind, _account} = subject, action, %DateTime{} = decided_at) when is_atom(action) do
    new(subject, action, %{now: decided_at})
  end

  @doc """
  The same names with empty values, which a call puts back when no call
  around it holds the connection. A rule reads a name at the empty string
  as "no action in force". No statement can unset a name.
  """
  @spec cleared(t()) :: t()
  def cleared(%__MODULE__{pairs: pairs}) do
    %__MODULE__{pairs: Enum.map(pairs, fn {name, _value} -> {name, ""} end)}
  end

  @doc """
  The names a call set, put back to what the call around it holds. A name
  the outer call set takes its value again. A name only the inner call set
  goes to the empty string. Each name appears once, so the order the
  database evaluates the calls in does not matter.
  """
  @spec restored(t(), t()) :: t()
  def restored(%__MODULE__{} = settings, %__MODULE__{pairs: outer}) do
    held = MapSet.new(outer, fn {name, _value} -> name end)
    %__MODULE__{pairs: pairs} = cleared(settings)
    %__MODULE__{pairs: Enum.reject(pairs, fn {name, _value} -> name in held end) ++ outer}
  end

  @doc "The one statement that sets them all, with its parameters."
  @spec to_sql(t()) :: {String.t(), [String.t()]}
  def to_sql(%__MODULE__{pairs: pairs}) do
    calls =
      pairs
      |> Enum.with_index()
      |> Enum.map_join(", ", fn {_pair, index} -> "set_config($#{2 * index + 1}, $#{2 * index + 2}, true)" end)

    {"SELECT " <> calls, Enum.flat_map(pairs, fn {name, value} -> [name, value] end)}
  end

  @doc "The sha256 of the settings, in lower-case hex."
  @spec hash(t()) :: String.t()
  def hash(%__MODULE__{pairs: pairs}) do
    text = Enum.map_join(pairs, "\n", fn {name, value} -> name <> "=" <> value end)
    Base.encode16(:crypto.hash(:sha256, text), case: :lower)
  end

  defp supplied(context) do
    context
    |> Map.drop(@fixed)
    |> Enum.sort_by(fn {name, _value} -> name end)
    |> Enum.map(fn {name, value} -> {to_string(name), value} end)
  end

  defp pair({name, value}), do: {@prefix <> to_string(name), render(value)}

  defp render(nil), do: ""
  defp render(value) when is_binary(value), do: value
  defp render(value) when is_atom(value), do: Atom.to_string(value)
  defp render(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp render(value) when is_number(value), do: to_string(value)
  defp render(value) when is_list(value), do: Enum.map_join(value, ",", &render/1)
  defp render(value), do: inspect(value)
end
