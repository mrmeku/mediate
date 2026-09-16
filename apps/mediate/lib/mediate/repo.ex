defmodule Mediate.Repo do
  @moduledoc """
  The seam. Its purpose is log completeness: no read or write of a
  protected schema goes unrecorded, because a call that carries no decision
  and no exemption raises before any SQL. It is not a reference monitor. It
  sees repo calls and nothing else, and no control asks it for more.

  `use Mediate.Repo` after `use Ecto.Repo` overrides every function of the
  Ecto surface the repo defines, and puts each in one of four buckets:

  - query: `all`, `one`, `get`, `get_by`, `reload`, `aggregate`, `exists?`,
    `stream`, `preload`, and `all_by`, with their bang forms. A read of a
    protected schema under a decision publishes one access event after it
    returns. `update_all` and `delete_all` sit here too, and refuse on an
    audited schema.
  - write: `insert`, `update`, `delete`, `insert_or_update`, and
    `insert_all`, with their bang forms. A single-row write to an audited
    schema publishes one change event inside its transaction.
  - raw: `query` and `query_many`, with their bang forms. A raw call passes
    under an exemption and refuses a decision.
  - plumbing: everything else passes.

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
        use Mediate.Repo
      end

  ## The `mediate:` option

  Every query, write, and raw call takes it, in one of three forms:

  - a `%Mediate.Decision{}` from `Mediate.authorize/4` or `Mediate.scope/4`
  - `{:exempt, reason}` with a non-empty reason, a declared exemption the
    seam records with the caller
  - `{:exempt, :library}`, which the seam accepts from a `Mediate.*` caller
    alone

  The root source of a query decides it. A protected root passes when the
  decision names its object type, when the parent's decision carries it
  through `carries/1`, or when the call is exempt. A joined or subquery
  source passes the same way, and a source with no schema or no object type
  passes without a check. A preload is a query of its own with the
  association's schema as root.

  A nested association write that Ecto makes on the caller's behalf reuses
  the parent's mediation, because Ecto forwards only `timeout`, `log`,
  `telemetry_event`, `prefix`, and `allow_stale` to it. `prepare_query/3`
  is the extension point: the seam judges every query there, and an
  adapter wraps every mediated call through `around_query/3`.

  ## What refuses

  - `%Mediate.Error{reason: :unmediated}` for a call on a protected schema
    with no decision and no exemption.
  - `%Mediate.Error{reason: :invalid}` with `:bulk_write` in the detail for
    `update_all`, `delete_all`, and `insert_all` on an audited schema, with
    `:upsert` for a write with `on_conflict:` on a fact schema, and with
    `:mediate` for a raw call given a decision.
  - `%Mediate.Error{}` with the denial's own reason, one of
    `Mediate.Answer.reasons/0`, for a deny decision handed to a call.

  ## Options

  - `role:` `:app`, the application's repo, or `:owner`, the library's own
    channel. Defaults to `:app`.

  An owner-role repo runs migrations and the library's own writes. Every
  call on it carries the library exemption, and it records nothing.
  """

  @schema NimbleOptions.new!(
            role: [
              type: {:in, [:app, :owner]},
              default: :app,
              doc: "`:app`, the application's repo, or `:owner`, the library's own channel."
            ]
          )

  @typedoc "One function of the surface the repo compiled against: its name, its arity, and its bucket."
  @type entry :: {atom(), non_neg_integer(), :query | :write | :raw | :plumbing}

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      Mediate.Repo.__check_order__(__MODULE__)
      @mediate_role Mediate.Repo.__role__(opts)
      @mediate_surface Mediate.Infrastructure.Surface.all()
      @before_compile Mediate.Infrastructure.Overrides

      @doc "The repo's role in Mediate, `:app` or `:owner`."
      @spec __mediate__(:role) :: :app | :owner
      def __mediate__(:role), do: @mediate_role
    end
  end

  @doc false
  @spec __check_order__(module()) :: :ok
  def __check_order__(module) do
    if Module.defines?(module, {:__adapter__, 0}) do
      :ok
    else
      raise ArgumentError, "use Mediate.Repo must follow use Ecto.Repo in #{inspect(module)}"
    end
  end

  @doc false
  @spec __role__(keyword()) :: :app | :owner
  def __role__(opts) do
    opts
    |> NimbleOptions.validate!(@schema)
    |> Keyword.fetch!(:role)
  end
end
