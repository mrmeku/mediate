defmodule Mediate.Postgres.Domain.Identifier do
  @moduledoc false
  # A table, column, role, or policy name on its way into a statement. A
  # name cannot be a parameter, so every one this package interpolates
  # passes `check!/2` first. A name that fits is a lowercase letter or
  # underscore, then lowercase letters, digits, and underscores, within the
  # 63 bytes an identifier can hold. A name that does not fit raises and
  # never reaches the database.

  alias Mediate.Error

  @plain ~r/\A[a-z_][a-z0-9_]*\z/
  @limit 63

  @doc "The name, or a raise that says which name it refused and what kind of name it was."
  @spec check!(atom() | String.t(), atom()) :: String.t()
  def check!(name, kind) when is_atom(name) and not is_nil(name), do: check!(Atom.to_string(name), kind)

  def check!(name, kind) when is_binary(name) and is_atom(kind) do
    if Regex.match?(@plain, name) and byte_size(name) <= @limit do
      name
    else
      raise Error.invalid(kind, "#{inspect(name)} is not a lowercase identifier of at most #{@limit} bytes")
    end
  end
end
