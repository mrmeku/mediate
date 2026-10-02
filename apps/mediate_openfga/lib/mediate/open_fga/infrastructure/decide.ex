defmodule Mediate.OpenFGA.Infrastructure.Decide do
  @moduledoc false
  # The verdicts the engine gives. An action becomes a relation. A subject
  # and a resource become the two ends of a tuple. The server answers
  # whether a path joins them.
  #
  # An action is the relation `can_` and its name. That is the one
  # translation this package makes. A subject is a user of the store
  # whatever kind it carries, because a graph compares by a walk and not by
  # equality. An allowance names that relation as the rule that allowed. A
  # denial is no rule matched. A graph has no rule that denies, it has no
  # path, and a rule named as the one that denied does not exist.
  #
  # The context is what the server evaluates a condition on a tuple
  # against. It holds the caller's facts under their own names. It holds
  # the moment of the call under `current_time`, and the kind of the
  # subject that asks under `subject_kind`. Those two keys this package
  # reserves. So a condition that compares a date on a tuple with the
  # present needs nothing of the caller, and the same holds for one that
  # compares the kind on a tuple with the kind that asks. The user string
  # stays kind-blind.
  #
  # An entry is where the question goes and what it asks under: the client,
  # the address, the store id, the model id, and that context. Every
  # verdict carries the model id as its policy version. The consistency of
  # each call is a constant of this package. A decision asks for the higher
  # consistency, so it misses no tuple a sync has written. A filter asks
  # for the lower one, since a filter is over rows the caller reads anyway.
  #
  # A filter is one `ListObjects`. Under the limit its ids become the
  # rule. At the limit the listing may be short of the truth and says
  # nothing about it. So the filter fails, and the library authorizes each
  # row instead.
  #
  # A guard is a rule outside the graph. Where the binding names one and it
  # does not admit the action, this module answers the denial and asks
  # nothing. That denial names the guard as the rule that denied, because
  # something denied it and not nothing allowed it.
  #
  # An action the model has no relation for is a question the server
  # refuses. This module answers that refusal as it stands and turns it
  # into no denial of its own. Nothing here can tell an action no one
  # declared from a model someone released wrong. Either way the caller
  # denies.

  import Ecto.Query, only: [dynamic: 2]

  alias Mediate.Error
  alias Mediate.OpenFGA.Client
  alias Mediate.OpenFGA.Client.Check
  alias Mediate.OpenFGA.Client.ListObjects
  alias Mediate.OpenFGA.Consistency
  alias Mediate.OpenFGA.TupleKey
  alias Mediate.Verdict

  @guard "guard"
  @limit 1_000
  @time "current_time"
  @kind "subject_kind"

  @typedoc "Where a question goes and what it asks under."
  @type entry :: %{
          callback: atom(),
          client: module(),
          address: Client.address(),
          store_id: Client.store_id(),
          model_id: Client.model_id() | nil,
          context: map()
        }

  @doc "The rule a refusal names, which is the guard and not anything of the model."
  @spec guard_rule() :: String.t()
  def guard_rule, do: @guard

  @doc "How many objects one `ListObjects` answers with at most, the server's own limit."
  @spec limit() :: pos_integer()
  def limit, do: @limit

  @doc "The key the moment of the call carries in the context of every question."
  @spec time_key() :: String.t()
  def time_key, do: @time

  @doc "The key the kind of the subject that asks carries in the context of every question."
  @spec kind_key() :: String.t()
  def kind_key, do: @kind

  @doc "The consistency each callback asks for, a constant of this package."
  @spec consistency(atom()) :: Consistency.t()
  def consistency(:filter), do: :minimize_latency
  def consistency(callback) when is_atom(callback), do: :higher_consistency

  @doc "The relation an action is."
  @spec relation(atom()) :: String.t()
  def relation(action) when is_atom(action), do: "can_" <> Atom.to_string(action)

  @doc "The user a subject is, whatever kind it carries."
  @spec user(Mediate.subject()) :: String.t()
  def user({_kind, id}), do: "user:#{id}"

  @doc "The object a resource is."
  @spec object(Mediate.resource()) :: String.t()
  def object({type, id}), do: "#{type}:#{id}"

  @doc "What the configuration entry names, or an engine error that names what it does not."
  @spec entry(keyword(), atom(), Mediate.context()) :: {:ok, entry()} | {:error, Error.t()}
  def entry(options, callback, %{now: _now} = context) when is_list(options) and is_atom(callback) do
    with {:ok, address} <- fetched(options, :address, callback),
         {:ok, store_id} <- fetched(options, :store_id, callback) do
      {:ok,
       %{
         callback: callback,
         client: Keyword.get(options, :client, Client.HTTP),
         address: address,
         store_id: store_id,
         model_id: Keyword.get(options, :model_id),
         context: context(context)
       }}
    end
  end

  @doc "The verdict of one question: one `Check` under the pinned model."
  @spec one(entry(), Mediate.subject(), atom(), Mediate.resource()) :: {:ok, Verdict.t()} | {:error, Error.t()}
  def one(entry, {_kind, _account} = subject, action, {_type, _id} = resource) when is_atom(action) do
    with {:ok, model_id} <- pinned(entry),
         request = check(entry, subject, action, resource, model_id),
         {:ok, allowed?} <- entry.client.check(entry.address, entry.store_id, request) do
      {:ok, verdict(allowed?, action, model_id)}
    end
  end

  @doc """
  The rule for a resource type: the ids `ListObjects` answers with, as a
  `dynamic` over the rows of that type. A listing at the limit fails,
  and the library authorizes each row instead.
  """
  @spec filter(entry(), Mediate.subject(), atom(), atom()) ::
          {:ok, Mediate.Engine.filtered()} | {:error, Error.t()}
  def filter(entry, {_kind, _account} = subject, action, type) when is_atom(action) and is_atom(type) do
    with {:ok, model_id} <- pinned(entry),
         {:ok, objects} <- listed(entry, subject, action, type, model_id),
         {:ok, ids} <- under_limit(objects) do
      {:ok, {dynamic([row], row.id in ^ids), verdict(true, action, model_id)}}
    end
  end

  @doc "The denial a guard's refusal is for one resource, under the entry's model."
  @spec refused(entry()) :: Verdict.t()
  def refused(entry) do
    %Verdict{effect: :deny, reason: :rule_denied, policy_version: entry.model_id, meta: %{rule: @guard}}
  end

  @doc "The filter a guard's refusal is: the rule no row satisfies, and the denial."
  @spec refused_filter(entry()) :: Mediate.Engine.filtered()
  def refused_filter(entry), do: {dynamic([_row], false), refused(entry)}

  defp listed(entry, {_kind, _account} = subject, action, type, model_id) do
    request = listing(entry, subject, action, type, model_id)

    entry.client.list_objects(entry.address, entry.store_id, request)
  end

  defp check(entry, {_kind, _account} = subject, action, {_type, _id} = resource, model_id) do
    %Check{
      tuple_key: tuple(subject, action, resource),
      model_id: model_id,
      context: asked_by(entry, subject),
      consistency: consistency(entry.callback)
    }
  end

  defp listing(entry, {_kind, _account} = subject, action, type, model_id) do
    %ListObjects{
      user: user(subject),
      relation: relation(action),
      type: Atom.to_string(type),
      model_id: model_id,
      context: asked_by(entry, subject),
      consistency: consistency(entry.callback)
    }
  end

  # The entry's context with the kind of the subject that asks, since the
  # user string carries none of it.
  defp asked_by(entry, {kind, _account}), do: Map.put(entry.context, @kind, Atom.to_string(kind))

  defp tuple({_kind, _account} = subject, action, {_type, _id} = resource) do
    %TupleKey{user: user(subject), relation: relation(action), object: object(resource)}
  end

  # At the limit the answer is a page of a longer list, and the server says
  # so by no means other than its length. So a list this long is no rule.
  defp under_limit(objects) when length(objects) < @limit, do: {:ok, Enum.map(objects, &id/1)}

  defp under_limit(objects) do
    text = "the server answered #{length(objects)} objects, the most one list holds, so the list may be short"

    {:error, Client.error(:filter, text <> "; authorize each row instead")}
  end

  defp id(object) do
    case String.split(object, ":", parts: 2) do
      [_type, id] -> id
      [id] -> id
    end
  end

  # The caller's facts under their own names, and the moment of the call. A
  # date goes as text, which is what a condition compares timestamps as.
  defp context(%{now: now} = context) do
    facts = Map.to_list(Map.delete(context, :now))
    Map.new([{@time, now} | facts], fn {name, value} -> {to_string(name), value(value)} end)
  end

  defp value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp value(%Date{} = value), do: Date.to_iso8601(value)
  defp value(value), do: value

  defp verdict(true, action, model_id) do
    %Verdict{effect: :allow, reason: :rule_allowed, policy_version: model_id, meta: %{rule: relation(action)}}
  end

  defp verdict(false, _action, model_id) do
    %Verdict{effect: :deny, reason: :no_rule_matched, policy_version: model_id, meta: %{}}
  end

  defp pinned(%{model_id: nil, callback: callback}) do
    {:error, Client.error(callback, "the configuration entry pins no model, so no question can be asked under one")}
  end

  defp pinned(%{model_id: model_id}), do: {:ok, model_id}

  defp fetched(options, field, callback) do
    case Keyword.fetch(options, field) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, Client.error(callback, "invalid engine: the configuration entry names no #{field}")}
    end
  end
end
