defmodule Example.Application.Repositories.RollupViolation do
  @moduledoc "A rollup that admits a subject a directory denies. The rollup does not include the directories' own."

  alias Example.Domain.Restrictions

  @enforce_keys [:repository_id, :rollup, :directories]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          repository_id: integer(),
          rollup: Restrictions.visibility(),
          directories: Restrictions.visibility()
        }
end

defmodule Example.Application.Repositories.OverrideRefused do
  @moduledoc "Why the application module refused an override: the account is not privileged, lacks the permission, or gave no justification."

  @enforce_keys [:reason]
  defstruct @enforce_keys

  @type t :: %__MODULE__{reason: :not_privileged | :no_permission | :no_justification}
end

defmodule Example.Application.Repositories do
  @moduledoc """
  Repositories, their rollups, their directories, and the audited override.
  Every read and write asks Mediate first and passes the decision to the
  mediated repo. The application module keeps the rollup (C4) at write
  time. The override read (C10) is the one path that reads outside C1. It
  runs under a declared exemption, with an override event and an override
  report of its own.

  A change that reaches many repositories at once writes a row at a time
  under the one decision `filter` answers with. So every identity write
  event it makes carries that decision's id.
  """

  alias Ecto.Changeset
  alias Example.Application.Accounts
  alias Example.Application.Repositories.OverrideRefused
  alias Example.Application.Repositories.RollupViolation
  alias Example.Domain.Directory
  alias Example.Domain.OverrideReport
  alias Example.Domain.Repository
  alias Example.Domain.Rollup
  alias Example.Domain.Visibility
  alias Example.Infrastructure.Repo
  alias Example.Infrastructure.RepositoryQuery
  alias Mediate.Config
  alias Mediate.Decision
  alias Mediate.Error

  @rollup {:exempt, "rollup: the directories' visibilities are read to derive the repository's rollup"}
  @override {:exempt,
             "audited override: the read outside C1 that C10 permits; it emits the override event and leaves an override report"}
  @override_event [:example, :override, :read]

  @typedoc "What an application module returns when Mediate refuses."
  @type refusal :: Error.t() | :not_found

  @doc "The actions on a repository, in the order the access review prints them."
  @spec actions() :: [atom()]
  def actions, do: [:read, :checkout, :change_visibility, :set_embargo, :lift_embargo, :propose_visibility]

  @doc "The override event: the telemetry event an override read emits, beside Mediate's own."
  @spec override_event() :: [atom()]
  def override_event, do: @override_event

  @doc "Read a repository with its rollup, under C1 and C2."
  @spec read(Mediate.subject(), integer(), keyword()) :: {:ok, Repository.t()} | {:error, refusal()}
  def read({_kind, _account} = subject, id, opts \\ []) when is_integer(id) and is_list(opts) do
    with {:ok, decision} <- Mediate.authorize(subject, :read, resource(id), opts) do
      fetch(id, decision)
    end
  end

  @doc "Read a repository under C1 alone, with the directories the subject can read and no other."
  @spec checkout(Mediate.subject(), integer(), keyword()) :: {:ok, Repository.t()} | {:error, refusal()}
  def checkout({_kind, _account} = subject, id, opts \\ []) when is_integer(id) and is_list(opts) do
    with {:ok, decision} <- Mediate.authorize(subject, :checkout, resource(id), opts),
         {:ok, repository} <- fetch(id, decision) do
      {:ok, %{repository | directories: directories(repository, subject, opts)}}
    end
  end

  @doc "The repositories the subject can read: the rows `filter` admits."
  @spec list(Mediate.subject(), keyword()) :: [Repository.t()]
  def list({_kind, _account} = subject, opts \\ []) when is_list(opts) do
    case Mediate.filter(subject, :read, :repository, opts) do
      {_rule, %Decision{effect: :deny}} ->
        []

      {rule, decision} ->
        Repo.all(RepositoryQuery.filtered(rule), authorized_by: decision)
    end
  end

  @doc """
  Change a repository's rollup (C7, C8). The application module refuses a rollup that
  admits a subject a directory denies (C4).
  """
  @spec change_visibility(Mediate.subject(), integer(), map(), keyword()) ::
          {:ok, Visibility.t()} | {:error, refusal() | RollupViolation.t()}
  def change_visibility({_kind, _account} = subject, id, attrs, opts \\ []) when is_integer(id) and is_map(attrs) do
    with {:ok, decision} <- Mediate.authorize(subject, :change_visibility, resource(id), opts) do
      apply_visibility(id, attrs, decision)
    end
  end

  @doc """
  Apply a visibility to a repository's rollup under a decision that admits the
  repository, and keep C4. The visibility is a nested change of the repository,
  because the repository's decision carries its visibility and no other decision
  names it.
  """
  @spec apply_visibility(integer(), map(), Decision.t()) :: {:ok, Visibility.t()} | {:error, RollupViolation.t()}
  def apply_visibility(id, attrs, %Decision{} = decision) when is_integer(id) and is_map(attrs) do
    Repo.transaction(fn ->
      with {:ok, repository} <- fetch(id, decision),
           {:ok, change} <- visibility_changeset(repository, attrs) do
        change
        |> Repo.update!(authorized_by: decision)
        |> Map.fetch!(:visibility)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  The changeset of a loaded repository that applies a visibility to its
  rollup. It is an error when the rollup admits a subject a directory denies
  (C4). The caller writes it under a decision that carries the repository.
  """
  @spec visibility_changeset(Repository.t(), map()) :: {:ok, Changeset.t()} | {:error, RollupViolation.t()}
  def visibility_changeset(%Repository{visibility: %Visibility{} = visibility} = repository, attrs) when is_map(attrs) do
    with :ok <- included(repository.id, attrs) do
      {:ok, Changeset.put_assoc(Changeset.change(repository), :visibility, Visibility.changeset(visibility, attrs))}
    end
  end

  @doc "A repository with its visibility, under a decision or an exemption that admits it, or `{:error, :not_found}` for no row."
  @spec fetch(integer(), Decision.t() | {:exempt, String.t()}) :: {:ok, Repository.t()} | {:error, :not_found}
  def fetch(id, authorized_by) when is_integer(id) do
    case Repo.get(Repository, id, authorized_by: authorized_by) do
      %Repository{} = repository -> {:ok, Repo.preload(repository, :visibility, authorized_by: authorized_by)}
      nil -> {:error, :not_found}
    end
  end

  @doc "Set a repository's embargo date (C7, C8)."
  @spec set_embargo(Mediate.subject(), integer(), DateTime.t(), keyword()) ::
          {:ok, Repository.t()} | {:error, refusal()}
  def set_embargo({_kind, _account} = subject, id, %DateTime{} = at, opts \\ []) when is_integer(id) do
    with {:ok, decision} <- Mediate.authorize(subject, :set_embargo, resource(id), opts),
         {:ok, repository} <- fetch(id, decision) do
      {:ok, Repo.update!(Changeset.change(repository, embargo: DateTime.truncate(at, :second)), authorized_by: decision)}
    end
  end

  @doc "Lift a repository's embargo now, by Mediate's clock (C5, C7, C8)."
  @spec lift_embargo(Mediate.subject(), integer(), keyword()) :: {:ok, Repository.t()} | {:error, refusal()}
  def lift_embargo({_kind, _account} = subject, id, opts \\ []) when is_integer(id) do
    with {:ok, decision} <- Mediate.authorize(subject, :lift_embargo, resource(id), opts),
         {:ok, repository} <- fetch(id, decision) do
      {:ok,
       Repo.update!(Changeset.change(repository, embargo: DateTime.truncate(decision.decided_at, :second)),
         authorized_by: decision
       )}
    end
  end

  @doc """
  Change a directory's visibility (C7 on the directory and on its repository) and
  recompute the repository's rollup in the same transaction (C4).
  """
  @spec change_directory_visibility(Mediate.subject(), integer(), map(), keyword()) ::
          {:ok, Directory.t()} | {:error, refusal()}
  def change_directory_visibility({_kind, _account} = subject, directory_id, attrs, opts \\ [])
      when is_integer(directory_id) and is_map(attrs) do
    with {:ok, directory_decision} <-
           Mediate.authorize(subject, :change_visibility, resource(:directory, directory_id), opts),
         {:ok, directory} <- fetch_directory(directory_id, directory_decision),
         {:ok, decision} <- Mediate.authorize(subject, :change_visibility, resource(directory.repository_id), opts) do
      Repo.transaction(fn ->
        updated = Repo.update!(Directory.changeset(directory, attrs), authorized_by: directory_decision)
        :ok = recompute_rollup(directory.repository_id, decision)
        updated
      end)
    end
  end

  @doc """
  The audited override (C10): a privileged account that holds the override
  permission reads a repository outside C1 with a justification. The read
  emits the override event, and the application module leaves an override
  report for the owning team. Nothing else is reachable through it.
  """
  @spec override_read(Mediate.subject(), integer(), String.t(), keyword()) ::
          {:ok, Repository.t()} | {:error, OverrideRefused.t() | :not_found}
  def override_read({kind, account} = subject, id, justification, opts \\ []) when is_integer(id) and is_list(opts) do
    with :ok <- override_permitted(subject, justification),
         {:ok, repository} <- fetch(id, @override) do
      correlation_id = Keyword.get_lazy(opts, :correlation_id, &Mediate.Id.new/0)
      report = report_override(repository, subject, justification, correlation_id)
      subject_ref = %{type: Atom.to_string(kind), id: account}
      :telemetry.execute(@override_event, %{}, %{subject: subject_ref, report: report})
      {:ok, repository}
    end
  end

  @doc "The override reports of a team, oldest first."
  @spec override_reports(integer()) :: [OverrideReport.t()]
  def override_reports(team_id) when is_integer(team_id) do
    Repo.all(RepositoryQuery.override_reports(team_id))
  end

  @doc "The resource for a repository id."
  @spec resource(integer()) :: Mediate.resource()
  def resource(id) when is_integer(id), do: {:repository, id}

  @doc "The resource for a row of a type."
  @spec resource(atom(), integer()) :: Mediate.resource()
  def resource(type, id) when is_atom(type) and is_integer(id), do: {type, id}

  defp included(repository_id, attrs) do
    directories = Repo.all(RepositoryQuery.directories(repository_id), authorized_by: @rollup)
    rollup = Rollup.visibility(attrs)
    required = Rollup.of(directories)

    if Rollup.includes?(rollup, required) do
      :ok
    else
      {:error, %RollupViolation{repository_id: repository_id, rollup: rollup, directories: required}}
    end
  end

  # The repository's own visibility is one input beside the directories'. So a
  # stricter directory tightens the rollup, and the repository's own values
  # stand where no directory is stricter.
  defp recompute_rollup(repository_id, decision) do
    {:ok, %Repository{visibility: visibility} = repository} = fetch(repository_id, decision)
    directories = Repo.all(RepositoryQuery.directories(repository_id), authorized_by: @rollup)
    rollup = Rollup.of([visibility | directories])
    change = Changeset.put_assoc(Changeset.change(repository), :visibility, Visibility.changeset(visibility, rollup))
    _repository = Repo.update!(change, authorized_by: decision)
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

  defp report_override(%Repository{} = repository, {_kind, account_id}, justification, correlation_id) do
    Repo.insert!(%OverrideReport{
      repository_id: repository.id,
      team_id: repository.owning_team_id,
      account_id: account_id,
      justification: justification,
      correlation_id: correlation_id,
      read_at: now()
    })
  end

  defp directories(%Repository{id: id}, subject, opts) do
    case Mediate.filter(subject, :read, :directory, opts) do
      {_rule, %Decision{effect: :deny}} ->
        []

      {rule, decision} ->
        Repo.all(RepositoryQuery.directories(id, rule), authorized_by: decision)
    end
  end

  defp fetch_directory(directory_id, decision) do
    case Repo.get(Directory, directory_id, authorized_by: decision) do
      %Directory{} = directory -> {:ok, directory}
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
