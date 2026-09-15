defmodule Mediate.Credo.UnmediatedRepoTest do
  use Credo.Test.Case, async: true

  alias Mediate.Credo.UnmediatedRepo

  # Credo is a compile-time dependency, and its parser services run as an
  # application. Under `mix quality` the credo task has already started that
  # application's supervisor in this VM. The start then reports
  # `already_started`. The services are up either way.
  setup_all do
    case Application.ensure_all_started(:credo) do
      {:ok, _started} -> :ok
      {:error, {:credo, {{:already_started, _pid}, _start}}} -> :ok
    end
  end

  test "use Ecto.Repo without use Mediate.Repo is flagged at the use line" do
    """
    defmodule MyApp.Repo do
      use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
    end
    """
    |> to_source_file()
    |> run_check(UnmediatedRepo)
    |> assert_issue(fn issue ->
      assert issue.line_no == 2
      assert issue.trigger == "use Ecto.Repo"
    end)
  end

  test "a repo with the seam, in either role, passes" do
    """
    defmodule MyApp.Repo do
      use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
      use Mediate.Repo
    end

    defmodule MyApp.OwnerRepo do
      use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
      use Mediate.Repo, role: :owner
    end
    """
    |> to_source_file()
    |> run_check(UnmediatedRepo)
    |> refute_issues()
  end

  test "a nested module's use lines belong to the nested module" do
    """
    defmodule MyApp do
      defmodule Repo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
      end

      use Mediate.Repo
    end
    """
    |> to_source_file()
    |> run_check(UnmediatedRepo)
    |> assert_issue(fn issue -> assert issue.line_no == 3 end)
  end
end
