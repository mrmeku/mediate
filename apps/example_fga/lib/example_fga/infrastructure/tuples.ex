defmodule ExampleFga.Infrastructure.Tuples do
  @moduledoc false
  # Hidden, because what the drain names is the mapping and not this module.
  # What is here is the half of the mapping that reads no row: the tuples a
  # row states, once the mapping has fetched the row. Three shapes carry the
  # translation:
  #
  # - An account's role on an object is a relation of that object.
  # - A restriction that applies is the wildcard `user:*` on the relation named
  #   for it. So what a visibility states is one fact about the object and not
  #   a tuple per account.
  # - An embargo date is the condition `under_embargo` with the date in
  #   it. So a date that passes needs no drain.

  alias Mediate.Fga.Condition
  alias Mediate.Fga.TupleKey

  @condition "under_embargo"

  @applies %{
    employees_only: "employee_applies",
    export_controlled: "export_applies",
    releasable_to: "regions_applies",
    invite_only: "invite_applies"
  }

  # A label implies EMPLOYEE ONLY or EXPORT and neither of the other two. REGIONS
  # rests on the countries a visibility names, and INVITE ONLY on the accounts
  # it invites. A label carries neither.
  @implied %{employees_only: "employee_applies", export_controlled: "export_applies"}

  @doc "An object of a type, as the model names it."
  @spec named(String.t(), [term()]) :: [String.t()]
  def named(type, values) when is_binary(type), do: for(value <- Enum.uniq(values), do: "#{type}:#{value}")

  @doc "One tuple, with no condition on it."
  @spec key(String.t(), String.t(), String.t()) :: TupleKey.t()
  def key(user, relation, object) when is_binary(user) and is_binary(relation) and is_binary(object) do
    %TupleKey{user: user, relation: relation, object: object}
  end

  @doc "The condition an embargo date puts on a tuple, or none where there is no date."
  @spec lapsing(DateTime.t() | nil) :: Condition.t() | nil
  def lapsing(nil), do: nil

  def lapsing(%DateTime{} = at) do
    %Condition{name: @condition, context: %{"lifts_at" => DateTime.to_iso8601(at)}}
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

  @doc "The restrictions a sensitive label implies, as wildcards on the label."
  @spec implied([atom()], String.t()) :: [TupleKey.t()]
  def implied(restrictions, object) when is_list(restrictions) and is_binary(object) do
    for restriction <- Enum.uniq(restrictions), relation = @implied[restriction], do: key("user:*", relation, object)
  end

  @doc "The accounts an INVITE ONLY visibility invites, which is a column of it rather than a row per account."
  @spec invited([term()], String.t()) :: [TupleKey.t()]
  def invited(accounts, object) when is_list(accounts) and is_binary(object) do
    for account <- Enum.uniq(accounts), do: key("user:#{account}", "invited", object)
  end

  @doc """
  The three things a visibility states, read from the row that carries it:

  - the labels it names
  - the countries REGIONS releases to
  - the restrictions that apply

  The labels and the restrictions lapse with the date.
  """
  @spec visibility(map() | nil, String.t(), Condition.t() | nil) :: [TupleKey.t()]
  def visibility(nil, _object, _lapses), do: []

  def visibility(visibility, object, lapses) when is_binary(object) do
    labels(visibility, object, lapses) ++ releases(visibility, object) ++ flags(visibility, object, lapses)
  end

  defp labels(visibility, object, lapses) do
    for label <- Enum.uniq(visibility.labels) do
      %TupleKey{user: "label:#{label}", relation: "label", object: object, condition: lapses}
    end
  end

  defp releases(visibility, object) do
    for country <- Enum.uniq(visibility.releasable_to), do: key("country:#{country}", "releasable_to", object)
  end

  defp flags(visibility, object, lapses) do
    for restriction <- Enum.uniq(visibility.restrictions), relation = @applies[restriction] do
      %TupleKey{user: "user:*", relation: relation, object: object, condition: lapses}
    end
  end
end
