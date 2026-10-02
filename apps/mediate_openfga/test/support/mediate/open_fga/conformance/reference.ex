defmodule Mediate.OpenFGA.Conformance.Reference do
  @moduledoc """
  The reference world as tuples, read from its tables. A membership of an
  account on a folder is a tuple: the account holds the membership's role
  on that folder. An account's clearance is a tuple too: the account holds
  `member` on the clearance as an object of its own. A graph compares by a
  walk and not by equality. An item's folder is a tuple as well, so the
  model reaches an item's folder through it.

  A folder tuple carries the account's clearance, the kind that holds the
  membership, and its expiry, as the condition `grant_holds`. So a
  clearance or an expiry that changes is the same tuple key with another
  value on it. The sync deletes that tuple and writes it again, in two
  calls. That is the shape a control with a parameter has, in the world's
  own terms.

  The condition compares the kind on the tuple with the kind that asks,
  and the expiry with the moment. The context of every question carries
  both. A membership with no expiry carries the last moment a timestamp
  can name. A membership whose account has no clearance states no tuple at
  all. The model admits a role on a folder under that condition alone, and
  the server refuses a tuple that carries none of it.

  A write to a membership affects the folder it sits on. The write carries
  the folder where it moved it, and the row itself carries it where the
  write left it alone. A write to an account's clearance affects the
  clearances it moved between and every folder the account holds a
  membership on. The write carries none of those folders. A write to an
  item affects the item.
  """

  @behaviour Mediate.OpenFGA.Mapping

  import Ecto.Query, only: [from: 2]

  alias Mediate.Fixture.Account
  alias Mediate.Fixture.Folder
  alias Mediate.Fixture.Item
  alias Mediate.Fixture.Membership
  alias Mediate.OpenFGA.Condition
  alias Mediate.OpenFGA.Mapping
  alias Mediate.OpenFGA.TupleKey

  @condition "grant_holds"
  @exemption {:exempt, "conformance mapping"}
  @model "priv/conformance/model.fga"
  @never "9999-12-31T23:59:59Z"

  @doc "The path of the model file the reference tuples sit under."
  @spec model() :: Path.t()
  def model, do: @model

  @impl Mapping
  def object_types, do: ["clearance", "folder", "item"]

  @impl Mapping
  def objects(repo, "folder") do
    for id <- all(repo, from(folder in Folder, select: folder.id)), do: "folder:#{id}"
  end

  def objects(repo, "clearance") do
    query = from(account in Account, where: not is_nil(account.clearance), distinct: true, select: account.clearance)

    for value <- all(repo, query), do: "clearance:#{value}"
  end

  def objects(repo, "item") do
    for id <- all(repo, from(item in Item, select: item.id)), do: "item:#{id}"
  end

  def objects(_repo, _type), do: []

  @impl Mapping
  def affected(repo, %{schema: Membership, resource: {_type, id}, changes: changes}) do
    folders = Enum.uniq(moved(changes, :folder_id) ++ folder_of(repo, id))

    for folder <- folders, do: "folder:#{folder}"
  end

  def affected(repo, %{schema: Account, resource: {_type, account}, changes: changes}) do
    clearances = for value <- moved(changes, :clearance), is_binary(value), do: "clearance:#{value}"

    Enum.uniq(clearances ++ folders_of(repo, account))
  end

  def affected(_repo, %{schema: Item, resource: {_type, id}}), do: ["item:#{id}"]

  def affected(_repo, %{}), do: []

  @impl Mapping
  def tuples(repo, object) do
    case String.split(object, ":", parts: 2) do
      ["folder", id] -> folder_tuples(repo, id)
      ["clearance", value] -> clearance_tuples(repo, value)
      ["item", id] -> item_tuples(repo, id)
      _other -> []
    end
  end

  @doc "The condition a membership's tuple carries: the clearance, the kind that holds it, and the expiry as text."
  @spec condition(String.t(), atom(), DateTime.t() | nil) :: Condition.t()
  def condition(clearance, kind, expires_at) do
    context = %{"clearance" => clearance, "kind" => Atom.to_string(kind), "expires_at" => expiry(expires_at)}
    %Condition{name: @condition, context: context}
  end

  # The model restricts a role on a folder to a cleared account. So the
  # tuple has a condition to carry once the account has a clearance, and
  # an account with none holds nothing on the folder yet.
  defp folder_tuples(repo, id) do
    query =
      from(membership in Membership,
        join: account in Account,
        on: account.id == membership.account_id,
        where: membership.folder_id == ^id and not is_nil(account.clearance) and not is_nil(membership.role),
        select:
          {membership.account_id, membership.role, account.clearance, membership.subject_kind, membership.expires_at}
      )

    for {account, role, clearance, kind, expires_at} <- all(repo, query) do
      %TupleKey{
        user: "user:#{account}",
        relation: to_string(role),
        object: "folder:#{id}",
        condition: condition(clearance, kind, expires_at)
      }
    end
  end

  defp clearance_tuples(repo, value) do
    query = from(account in Account, where: account.clearance == ^value, select: account.id)

    for account <- all(repo, query) do
      %TupleKey{user: "user:#{account}", relation: "member", object: "clearance:#{value}"}
    end
  end

  defp item_tuples(repo, id) do
    query = from(item in Item, where: item.id == ^id, select: item.folder_id)

    for folder <- all(repo, query) do
      %TupleKey{user: "folder:#{folder}", relation: "folder", object: "item:#{id}"}
    end
  end

  # The folder a membership sits on now, for a write that left the column
  # alone. A delete carries both of its own, and a row that is gone answers
  # nothing here.
  defp folder_of(repo, id) do
    query = from(membership in Membership, where: membership.id == ^id, select: membership.folder_id)

    all(repo, query)
  end

  defp folders_of(repo, account) do
    query = from(membership in Membership, where: membership.account_id == ^account, select: membership.folder_id)

    for folder <- all(repo, query), do: "folder:#{folder}"
  end

  defp moved(changes, column) do
    case Map.fetch(changes, column) do
      {:ok, {was, now}} -> Enum.reject([was, now], &is_nil/1)
      :error -> []
    end
  end

  defp expiry(nil), do: @never
  defp expiry(%DateTime{} = expires_at), do: DateTime.to_iso8601(expires_at)

  defp all(repo, query), do: repo.all(query, authorized_by: @exemption)
end
