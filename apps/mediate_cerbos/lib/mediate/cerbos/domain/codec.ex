defmodule Mediate.Cerbos.Domain.Codec do
  @moduledoc false
  # A value on its way to the server. JSON carries numbers, strings,
  # booleans, and null. A value of any other shape crosses as text. So an
  # `Ecto.Enum` column reaches the server as the string the column holds,
  # and a date as its ISO 8601 form.
  #
  # The text form is what a policy compares. A plan compiled from that same
  # policy compares a database column against the value the policy carries.
  # `Ecto.Type.cast/2` reads that value back into the column's type. The two
  # agree only where cast answers the value that went in.
  #
  # `to_second/1` cuts a moment to the second first, because a column holds
  # microseconds that the text of a moment does not. A comparison between
  # the two is a comparison of different precisions.

  @doc "The value as JSON carries it, with a moment cut to the second."
  @spec to_second(term()) :: term()
  def to_second(%DateTime{} = value), do: encode(DateTime.truncate(value, :second))
  def to_second(value), do: encode(value)

  @doc "The value as JSON carries it."
  @spec encode(term()) :: term()
  def encode(nil), do: nil
  def encode(true), do: true
  def encode(false), do: false
  def encode(value) when is_atom(value), do: Atom.to_string(value)
  def encode(%Date{} = value), do: Date.to_iso8601(value)
  def encode(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def encode(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  def encode(%Time{} = value), do: Time.to_iso8601(value)
  def encode(value) when is_list(value), do: Enum.map(value, &encode/1)
  def encode(value), do: value
end
