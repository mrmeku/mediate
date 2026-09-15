defmodule ExampleFga.Infrastructure.Tuples do
  @moduledoc false
  # Hidden, because what the drain names is the mapping and not this module.
  # What is here is the half of the mapping that reads no row: the tuples a
  # row states, once the mapping has fetched the row. Three shapes carry the
  # translation:
  #
  # - An account's role on an object is a relation of that object.
  # - A control that applies is the wildcard `user:*` on the relation named
  #   for it. So what a marking states is one fact about the object and not
  #   a tuple per account.
  # - A decontrol date is the condition `before_decontrol` with the date in
  #   it. So a date that passes needs no drain.

  alias Mediate.Fga.Condition
  alias Mediate.Fga.TupleKey

  @condition "before_decontrol"

  @applies %{
    federal_only: "fedonly_applies",
    no_foreign: "noforn_applies",
    releasable_to: "relto_applies",
    named_list: "list_applies"
  }

  # A category implies FEDONLY or NOFORN and neither of the other two. REL TO
  # rests on the countries a marking names, and DL ONLY on the accounts it
  # lists. A category carries neither.
  @implied %{federal_only: "fedonly_applies", no_foreign: "noforn_applies"}

  @doc "An object of a type, as the model names it."
  @spec named(String.t(), [term()]) :: [String.t()]
  def named(type, values) when is_binary(type), do: for(value <- Enum.uniq(values), do: "#{type}:#{value}")

  @doc "One tuple, with no condition on it."
  @spec key(String.t(), String.t(), String.t()) :: TupleKey.t()
  def key(user, relation, object) when is_binary(user) and is_binary(relation) and is_binary(object) do
    %TupleKey{user: user, relation: relation, object: object}
  end

  @doc "The condition a decontrol date puts on a tuple, or none where there is no date."
  @spec lapsing(DateTime.t() | nil) :: Condition.t() | nil
  def lapsing(nil), do: nil

  def lapsing(%DateTime{} = at) do
    %Condition{name: @condition, context: %{"decontrol_at" => DateTime.to_iso8601(at)}}
  end

  @doc "One tuple per role an account holds on an object. An account with two roles holds both relations."
  @spec roles([{term(), atom()}], String.t()) :: [TupleKey.t()]
  def roles(held, object) when is_list(held) and is_binary(object) do
    for {account, role} <- held, do: key("user:#{account}", to_string(role), object)
  end

  @doc "Membership of a value reified as an object of its own, because a graph compares by a walk and not by equality."
  @spec members([term()], String.t()) :: [TupleKey.t()]
  def members(accounts, object) when is_list(accounts) and is_binary(object) do
    for account <- accounts, do: key("user:#{account}", "member", object)
  end

  @doc "The controls a specified category implies, as wildcards on the category."
  @spec implied([atom()], String.t()) :: [TupleKey.t()]
  def implied(controls, object) when is_list(controls) and is_binary(object) do
    for control <- Enum.uniq(controls), relation = @implied[control], do: key("user:*", relation, object)
  end

  @doc "The accounts a DL ONLY list names, which is a column of the banner rather than a row per account."
  @spec listed([term()], String.t()) :: [TupleKey.t()]
  def listed(list, object) when is_list(list) and is_binary(object) do
    for account <- Enum.uniq(list), do: key("user:#{account}", "listed", object)
  end

  @doc """
  The three things a marking states, read from the row that carries it:

  - the categories it names
  - the countries REL TO releases to
  - the controls that apply

  The categories and the controls lapse with the date.
  """
  @spec marking(map() | nil, String.t(), Condition.t() | nil) :: [TupleKey.t()]
  def marking(nil, _object, _lapses), do: []

  def marking(marking, object, lapses) when is_binary(object) do
    categories(marking, object, lapses) ++ releases(marking, object) ++ flags(marking, object, lapses)
  end

  defp categories(marking, object, lapses) do
    for category <- Enum.uniq(marking.categories) do
      %TupleKey{user: "category:#{category}", relation: "category", object: object, condition: lapses}
    end
  end

  defp releases(marking, object) do
    for country <- Enum.uniq(marking.releasable_to), do: key("country:#{country}", "releasable_to", object)
  end

  defp flags(marking, object, lapses) do
    for control <- Enum.uniq(marking.controls), relation = @applies[control] do
      %TupleKey{user: "user:*", relation: relation, object: object, condition: lapses}
    end
  end
end
