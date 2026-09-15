defmodule Example.Application.Documents.BannerViolation do
  @moduledoc "A banner that admits a subject a portion denies. The banner does not cover the portions' own."

  alias Example.Domain.Controls

  @enforce_keys [:document_id, :banner, :portions]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          document_id: integer(),
          banner: Controls.marking(),
          portions: Controls.marking()
        }
end

defmodule Example.Application.Documents.OverrideRefused do
  @moduledoc "Why the context refused an override: the account is not privileged, lacks the permission, or gave no justification."

  @enforce_keys [:reason]
  defstruct @enforce_keys

  @type t :: %__MODULE__{reason: :not_privileged | :no_permission | :no_justification}
end

defmodule Example.Application.Documents do
  @moduledoc """
  Documents, their banners, their portions, and the audited override. Every
  read and write asks the port first and passes the decision to the seam.
  The context enforces the banner invariant (C4) at write time. The override
  (C10) is the one path that reads outside C1. It runs under a declared
  exemption, with an event and a report of its own.

  A change that reaches many documents at once writes a row at a time under
  the one decision `scope` answers with. So every change event it makes
  carries that decision's operation id.
  """

  alias Ecto.Changeset
  alias Example.Application.Accounts
  alias Example.Application.Documents.BannerViolation
  alias Example.Application.Documents.OverrideRefused
  alias Example.Domain.Banner
  alias Example.Domain.Document
  alias Example.Domain.Marking
  alias Example.Domain.OverrideReport
  alias Example.Domain.Portion
  alias Example.Infrastructure.DocumentQuery
  alias Example.Infrastructure.Repo
  alias Mediate.Config
  alias Mediate.Decision
  alias Mediate.Error

  @banner {:exempt, "banner invariant: the portions' markings are read to derive the banner"}
  @override {:exempt, "audited override: the read outside C1 that C10 permits, evented and reported"}
  @override_event [:example, :override, :read]

  @typedoc "What a context function returns when the port refuses."
  @type refusal :: Error.t() | :not_found

  @doc "The operations on a document, in the order the review prints them."
  @spec operations() :: [atom()]
  def operations, do: [:read, :read_redacted, :change_marking, :set_decontrol, :decontrol, :propose_marking]

  @doc "The telemetry event an override read emits, beside the port's own."
  @spec override_event() :: [atom()]
  def override_event, do: @override_event

  @doc "Read a document with its banner, under C1 and C2."
  @spec read(Mediate.subject(), integer(), keyword()) :: {:ok, Document.t()} | {:error, refusal()}
  def read({_kind, _account} = subject, id, opts \\ []) when is_integer(id) and is_list(opts) do
    with {:ok, decision} <- Mediate.authorize(subject, :read, object(id), opts) do
      fetch(id, decision)
    end
  end

  @doc "Read a document under C1 alone, with the portions the subject can read and no other."
  @spec read_redacted(Mediate.subject(), integer(), keyword()) :: {:ok, Document.t()} | {:error, refusal()}
  def read_redacted({_kind, _account} = subject, id, opts \\ []) when is_integer(id) and is_list(opts) do
    with {:ok, decision} <- Mediate.authorize(subject, :read_redacted, object(id), opts),
         {:ok, document} <- fetch(id, decision) do
      {:ok, %{document | portions: portions(document, subject, opts)}}
    end
  end

  @doc "The documents the subject can read, under `scope`."
  @spec list(Mediate.subject(), keyword()) :: [Document.t()]
  def list({_kind, _account} = subject, opts \\ []) when is_list(opts) do
    case Mediate.scope(subject, :read, :document, opts) do
      {_rule, %Decision{verdict: :deny}} ->
        []

      {rule, decision} ->
        Repo.all(DocumentQuery.listed(rule), mediate: decision)
    end
  end

  @doc "Change a document's banner (C7, C8). The context refuses a banner that admits a subject a portion denies (C4)."
  @spec change_marking(Mediate.subject(), integer(), map(), keyword()) ::
          {:ok, Marking.t()} | {:error, refusal() | BannerViolation.t()}
  def change_marking({_kind, _account} = subject, id, attrs, opts \\ []) when is_integer(id) and is_map(attrs) do
    with {:ok, decision} <- Mediate.authorize(subject, :change_marking, object(id), opts) do
      apply_marking(id, attrs, decision)
    end
  end

  @doc """
  Apply a marking to a document's banner under a decision that admits the
  document, and keep C4. The marking is a nested change of the document,
  because the document's decision carries its marking and no other decision
  names it.
  """
  @spec apply_marking(integer(), map(), Decision.t()) :: {:ok, Marking.t()} | {:error, BannerViolation.t()}
  def apply_marking(id, attrs, %Decision{} = decision) when is_integer(id) and is_map(attrs) do
    Repo.transaction(fn ->
      with {:ok, document} <- fetch(id, decision),
           {:ok, change} <- marking_change(document, attrs) do
        change
        |> Repo.update!(mediate: decision)
        |> Map.fetch!(:marking)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  The change of a loaded document that applies a marking to its banner. It
  is an error when the banner admits a subject a portion denies (C4). The
  caller writes it under a decision that carries the document.
  """
  @spec marking_change(Document.t(), map()) :: {:ok, Changeset.t()} | {:error, BannerViolation.t()}
  def marking_change(%Document{marking: %Marking{} = marking} = document, attrs) when is_map(attrs) do
    with :ok <- covered(document.id, attrs) do
      {:ok, Changeset.put_assoc(Changeset.change(document), :marking, Marking.changeset(marking, attrs))}
    end
  end

  @doc "A document with its marking, under a mediation that admits it, or `{:error, :not_found}` for no row."
  @spec fetch(integer(), Decision.t() | {:exempt, String.t()}) :: {:ok, Document.t()} | {:error, :not_found}
  def fetch(id, mediation) when is_integer(id) do
    case Repo.get(Document, id, mediate: mediation) do
      %Document{} = document -> {:ok, Repo.preload(document, :marking, mediate: mediation)}
      nil -> {:error, :not_found}
    end
  end

  @doc "Set a document's decontrol date (C7, C8)."
  @spec set_decontrol(Mediate.subject(), integer(), DateTime.t(), keyword()) ::
          {:ok, Document.t()} | {:error, refusal()}
  def set_decontrol({_kind, _account} = subject, id, %DateTime{} = at, opts \\ []) when is_integer(id) do
    with {:ok, decision} <- Mediate.authorize(subject, :set_decontrol, object(id), opts),
         {:ok, document} <- fetch(id, decision) do
      {:ok, Repo.update!(Changeset.change(document, decontrol: DateTime.truncate(at, :second)), mediate: decision)}
    end
  end

  @doc "Decontrol a document now, by the port's clock (C5, C7, C8)."
  @spec decontrol(Mediate.subject(), integer(), keyword()) :: {:ok, Document.t()} | {:error, refusal()}
  def decontrol({_kind, _account} = subject, id, opts \\ []) when is_integer(id) do
    with {:ok, decision} <- Mediate.authorize(subject, :decontrol, object(id), opts),
         {:ok, document} <- fetch(id, decision) do
      {:ok,
       Repo.update!(Changeset.change(document, decontrol: DateTime.truncate(decision.at, :second)), mediate: decision)}
    end
  end

  @doc """
  Change a portion's marking (C7 on the portion and on its document) and
  recompute the document's banner in the same transaction (C4).
  """
  @spec change_portion_marking(Mediate.subject(), integer(), map(), keyword()) ::
          {:ok, Portion.t()} | {:error, refusal()}
  def change_portion_marking({_kind, _account} = subject, portion_id, attrs, opts \\ [])
      when is_integer(portion_id) and is_map(attrs) do
    with {:ok, portion_decision} <- Mediate.authorize(subject, :change_marking, object(:portion, portion_id), opts),
         {:ok, portion} <- fetch_portion(portion_id, portion_decision),
         {:ok, decision} <- Mediate.authorize(subject, :change_marking, object(portion.document_id), opts) do
      Repo.transaction(fn ->
        updated = Repo.update!(Portion.changeset(portion, attrs), mediate: portion_decision)
        :ok = recompute_banner(portion.document_id, decision)
        updated
      end)
    end
  end

  @doc """
  The audited override (C10): a privileged account that holds the override
  permission reads a document outside C1 with a justification. The read
  emits its own event, and the context reports it to the designating
  office. Nothing else is reachable through it.
  """
  @spec override_read(Mediate.subject(), integer(), String.t(), keyword()) ::
          {:ok, Document.t()} | {:error, OverrideRefused.t() | :not_found}
  def override_read({kind, account} = subject, id, justification, opts \\ []) when is_integer(id) and is_list(opts) do
    with :ok <- override_permitted(subject, justification),
         {:ok, document} <- fetch(id, @override) do
      operation_id = Keyword.get_lazy(opts, :operation_id, &Mediate.Id.new/0)
      report = report_override(document, subject, justification, operation_id)
      subject_ref = %{type: Atom.to_string(kind), id: account}
      :telemetry.execute(@override_event, %{}, %{subject: subject_ref, report: report})
      {:ok, document}
    end
  end

  @doc "The overrides reported to an office, oldest first."
  @spec override_reports(integer()) :: [OverrideReport.t()]
  def override_reports(office_id) when is_integer(office_id) do
    Repo.all(DocumentQuery.reports(office_id))
  end

  @doc "The object reference for a document id."
  @spec object(integer()) :: Mediate.object()
  def object(id) when is_integer(id), do: {:document, id}

  @doc "The object reference for a row of a type."
  @spec object(atom(), integer()) :: Mediate.object()
  def object(type, id) when is_atom(type) and is_integer(id), do: {type, id}

  defp covered(document_id, attrs) do
    portions = Repo.all(DocumentQuery.portions(document_id), mediate: @banner)
    banner = Banner.marking(attrs)
    required = Banner.of(portions)

    if Banner.covers?(banner, required) do
      :ok
    else
      {:error, %BannerViolation{document_id: document_id, banner: banner, portions: required}}
    end
  end

  # The document's own marking is one input beside the portions'. So a
  # stricter portion tightens the banner, and the document's own values
  # stand where no portion is stricter.
  defp recompute_banner(document_id, decision) do
    {:ok, %Document{marking: marking} = document} = fetch(document_id, decision)
    portions = Repo.all(DocumentQuery.portions(document_id), mediate: @banner)
    banner = Banner.of([marking | portions])
    change = Changeset.put_assoc(Changeset.change(document), :marking, Marking.changeset(marking, banner))
    _document = Repo.update!(change, mediate: decision)
    :ok
  end

  defp override_permitted({kind, _account}, _justification) when kind != :privileged do
    {:error, %OverrideRefused{reason: :not_privileged}}
  end

  defp override_permitted({_kind, _account}, justification) when not is_binary(justification) or justification == "" do
    {:error, %OverrideRefused{reason: :no_justification}}
  end

  defp override_permitted({_kind, id}, _justification) do
    if Accounts.override_permitted?(id),
      do: :ok,
      else: {:error, %OverrideRefused{reason: :no_permission}}
  end

  defp report_override(%Document{} = document, {_kind, user_id}, justification, operation_id) do
    Repo.insert!(%OverrideReport{
      document_id: document.id,
      office_id: document.designating_office_id,
      user_id: user_id,
      justification: justification,
      operation_id: operation_id,
      at: now()
    })
  end

  defp portions(%Document{id: id}, subject, opts) do
    case Mediate.scope(subject, :read, :portion, opts) do
      {_rule, %Decision{verdict: :deny}} ->
        []

      {rule, decision} ->
        Repo.all(DocumentQuery.portions(id, rule), mediate: decision)
    end
  end

  defp fetch_portion(portion_id, decision) do
    case Repo.get(Portion, portion_id, mediate: decision) do
      %Portion{} = portion -> {:ok, portion}
      nil -> {:error, :not_found}
    end
  end

  # Cut to the second, which is the precision of the moment a request
  # carries.
  defp now do
    {:ok, config} = Config.resolve()

    DateTime.truncate(config.clock.(), :second)
  end
end
