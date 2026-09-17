defmodule Example.Infrastructure.Migration do
  @moduledoc """
  The domain tables, as a helper a thin application's first migration
  calls. The library ships no migration files. Every table receives the
  application role's grants. No foreign key cascades into a fact schema, so
  a revocation deletes nothing but the fact.

      defmodule ExampleRbac.Repo.Migrations.Domain do
        use Ecto.Migration
        def up, do: Example.Infrastructure.Migration.up(app_role: "mediate_app")
        def down, do: Example.Infrastructure.Migration.down()
      end
  """

  import Ecto.Migration

  @schema NimbleOptions.new!(
            app_role: [
              type: :string,
              default: "mediate_app",
              doc: "The database role the application connects as, which receives the grants."
            ]
          )

  @serial_tables ~w(enterprises teams projects account_roles memberships team_roles repositories visibilities directories
    visibility_proposals override_reports)a
  @keyed_tables ~w(users labels)a

  @doc "Create the domain tables and the grants. Options: #{NimbleOptions.docs(@schema)}"
  @spec up(keyword()) :: :ok
  def up(options \\ []) when is_list(options) do
    options = NimbleOptions.validate!(options, @schema)
    tenancy()
    accounts()
    roles()
    repositories()
    proposals_and_reports()
    grants(options[:app_role])
    :ok
  end

  @doc "The tables the helper creates, as the schemas name them."
  @spec tables() :: [String.t()]
  def tables, do: Enum.map(@serial_tables ++ @keyed_tables, &Atom.to_string/1)

  @doc "Drop the domain tables, dependents first."
  @spec down() :: :ok
  def down do
    Enum.each(Enum.reverse(@serial_tables ++ @keyed_tables), &drop(table(&1)))
    :ok
  end

  defp tenancy do
    create table(:enterprises) do
      add :name, :text, null: false
      add :country, :text, null: false
    end

    create table(:teams) do
      add :name, :text, null: false
      add :enterprise_id, references(:enterprises), null: false
    end

    create table(:projects) do
      add :name, :text, null: false
      add :archived_at, :utc_datetime
      add :team_id, references(:teams), null: false
    end

    create table(:labels, primary_key: false) do
      add :name, :text, primary_key: true
      add :sensitive, :boolean, null: false, default: false
      add :implied_restrictions, {:array, :text}, null: false, default: []
    end
  end

  defp accounts do
    create table(:users, primary_key: false) do
      add :id, :text, primary_key: true
      add :name, :text, null: false
      add :kind, :text, null: false
      add :person_id, :text, null: false
      add :employment, :text, null: false
      add :country, :text, null: false
    end

    create table(:account_roles) do
      add :user_id, references(:users, type: :text), null: false
      add :role, :text, null: false
    end

    create unique_index(:account_roles, [:user_id, :role])
  end

  defp roles do
    create table(:memberships) do
      add :user_id, references(:users, type: :text), null: false
      add :project_id, references(:projects), null: false
      add :role, :text, null: false
    end

    create unique_index(:memberships, [:user_id, :project_id])

    create table(:team_roles) do
      add :user_id, references(:users, type: :text), null: false
      add :team_id, references(:teams), null: false
      add :role, :text, null: false
    end

    create unique_index(:team_roles, [:user_id, :team_id, :role])
  end

  defp repositories do
    create table(:repositories) do
      add :name, :text, null: false
      add :embargo, :utc_datetime
      add :project_id, references(:projects), null: false
      add :owning_team_id, references(:teams), null: false
    end

    create table(:visibilities) do
      add :repository_id, references(:repositories), null: false
      add :labels, {:array, :text}, null: false, default: []
      add :restrictions, {:array, :text}, null: false, default: []
      add :releasable_to, {:array, :text}, null: false, default: []
      add :invited, {:array, :text}, null: false, default: []
    end

    create unique_index(:visibilities, [:repository_id])

    create table(:directories) do
      add :repository_id, references(:repositories), null: false
      add :name, :text, null: false
      add :contents, :text, null: false
      add :labels, {:array, :text}, null: false, default: []
      add :restrictions, {:array, :text}, null: false, default: []
      add :releasable_to, {:array, :text}, null: false, default: []
    end
  end

  defp proposals_and_reports do
    create table(:visibility_proposals) do
      add :repository_id, references(:repositories), null: false
      add :proposer_id, references(:users, type: :text), null: false
      add :reviewer_id, references(:users, type: :text)
      add :status, :text, null: false, default: "pending"
      add :labels, {:array, :text}, null: false, default: []
      add :restrictions, {:array, :text}, null: false, default: []
      add :releasable_to, {:array, :text}, null: false, default: []
      add :invited, {:array, :text}, null: false, default: []
    end

    create table(:override_reports) do
      add :repository_id, references(:repositories), null: false
      add :team_id, references(:teams), null: false
      add :user_id, references(:users, type: :text), null: false
      add :justification, :text, null: false
      add :operation_id, :text, null: false
      add :at, :utc_datetime, null: false
    end
  end

  defp grants(app_role) do
    for name <- @serial_tables ++ @keyed_tables do
      execute "GRANT SELECT, INSERT, UPDATE, DELETE ON #{name} TO #{app_role}"
    end

    for name <- @serial_tables do
      execute "GRANT USAGE, SELECT ON SEQUENCE #{name}_id_seq TO #{app_role}"
    end
  end
end
