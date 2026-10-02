if Code.ensure_loaded?(Credo.Check) do
  defmodule Mediate.Credo.Check.Warning.UnmediatedRepo do
    use Credo.Check,
      id: "ME5002",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        A module that `use Ecto.Repo` without `use Mediate.Repo` answers
        every query and checks no decision, so nothing records what it runs.
        A mediated repo has a second `use` after Ecto's:

            use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres
            use Mediate.Repo

        A migration repo takes `use Mediate.Repo, role: :owner`, and both
        roles make a mediated repo. This check reads source text.
        `Mediate.Conformance.RepoCase` proves at run time what the mediated
        repo refuses.
        """
      ]

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    end

    defp walk({:defmodule, _meta, [{:__aliases__, _alias_meta, _parts}, [do: body]]} = ast, ctx) do
      uses = Credo.Code.prewalk(body, &collect_use/2, [])

      case {List.keyfind(uses, [:Ecto, :Repo], 0), List.keyfind(uses, [:Mediate, :Repo], 0)} do
        {{_ecto, meta}, nil} -> {ast, put_issue(ctx, issue_for(ctx, meta))}
        _other -> {ast, ctx}
      end
    end

    defp walk(ast, ctx), do: {ast, ctx}

    # A nested module's `use` lines are its own.
    defp collect_use({:defmodule, _meta, _args}, uses), do: {nil, uses}

    defp collect_use({:use, meta, [{:__aliases__, _alias_meta, parts} | _opts]} = ast, uses),
      do: {ast, [{parts, meta} | uses]}

    defp collect_use(ast, uses), do: {ast, uses}

    defp issue_for(ctx, meta) do
      format_issue(ctx,
        message:
          "`use Ecto.Repo` has no `use Mediate.Repo` after it, so nothing checks or records a query on this repo. " <>
            "Add `use Mediate.Repo` after `use Ecto.Repo`.",
        trigger: "use Ecto.Repo",
        line_no: meta[:line],
        column: meta[:column]
      )
    end
  end
end
