defmodule Mediate.Postgres.Infrastructure.Name do
  @moduledoc false
  # A table, column, or policy name on its way into a statement. A name
  # cannot be a parameter, so every one this package interpolates passes
  # `check!/2` first. A plain name is a lowercase letter or underscore, then
  # lowercase letters, digits, and underscores, up to the 63 bytes an
  # identifier can hold. A name that does not fit raises and never reaches
  # the database.

  alias Mediate.Error

  @plain ~r/\A[a-z_][a-z0-9_]*\z/
  @limit 63

  @doc "The name, or a raise that says which name it refused and what the name was for."
  @spec check!(atom() | String.t(), atom()) :: String.t()
  def check!(name, what) when is_atom(name) and not is_nil(name), do: check!(Atom.to_string(name), what)

  def check!(name, what) when is_binary(name) and is_atom(what) do
    if Regex.match?(@plain, name) and byte_size(name) <= @limit do
      name
    else
      raise Error.invalid(what, "#{inspect(name)} is not a plain lowercase identifier")
    end
  end
end
