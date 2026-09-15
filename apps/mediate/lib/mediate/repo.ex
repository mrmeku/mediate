defmodule Mediate.Repo do
  @moduledoc """
  The seam. `use Mediate.Repo` after `use Ecto.Repo` overrides every
  function of the Ecto surface the repo defines. So each call passes the
  `mediate:` option, a `Mediate.Decision` or an exemption, to the seam
  before Ecto runs it. A query on a protected schema without the option
  raises `Mediate.Error` before any SQL.

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
        use Mediate.Repo
      end

  ## Options

  - `role:` `:app`, the application's repo, or `:owner`, the library's own
    channel. Defaults to `:app`.

  An owner-role repo is the library's own channel. It runs migrations and
  the library's own writes. Every call on it carries the library exemption,
  and it records nothing. An application-role repo, the default, is the one
  the application queries through.
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
