if Code.ensure_loaded?(Credo.Check) do
  defmodule Mediate.Credo.Check.Warning.RawSQL do
    @moduledoc false
    use Credo.Check,
      id: "ME5001",
      base_priority: :high,
      category: :warning,
      param_defaults: [excluded_namespaces: []],
      explanations: [
        check: """
        Every query to the application's database goes through a repo that
        `use Mediate.Repo`. That repo refuses a call that carries no decision
        and no exemption in `authorized_by:`, and it records the call it
        runs. `Ecto.Adapters.SQL.query/4`, its variants, and any `Postgrex`
        call reach the database around the mediated repo, so nothing checks
        or records them.

        Call the repo with `authorized_by:` instead. A module the mediated
        repo itself rests on, such as an outbox writer or a test cluster's
        bootstrap, goes in `excluded_namespaces` by module name prefix, and
        no other module does. A call outside any module cannot be excluded.
        This check reads source text. `Mediate.Conformance.RepoCase` proves
        at run time what the mediated repo refuses.
        """,
        params: [
          excluded_namespaces:
            "Module name prefixes the check skips, as strings: the modules the mediated repo itself rests on."
        ]
      ]

    alias Credo.Code.Name

    @sql_functions [:query, :query!, :query_many, :query_many!]

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__, %{module: nil})
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    end

    defp walk({:defmodule, _meta, [{:__aliases__, _alias_meta, parts}, [do: body]]}, ctx) do
      name = nested(ctx.module, Name.full(parts))
      inner = Credo.Code.prewalk(body, &walk/2, %{ctx | module: name})
      {nil, %{ctx | issues: inner.issues}}
    end

    # The issue points at the alias, where the trigger text starts.
    defp walk({{:., _dot_meta, [{:__aliases__, meta, parts}, function]}, _call_meta, _args} = ast, ctx) do
      case raw(parts, function) do
        nil -> {ast, ctx}
        trigger -> {ast, put_issue(ctx, issue_for(ctx, meta, trigger))}
      end
    end

    defp walk(ast, ctx), do: {ast, ctx}

    defp nested(nil, name), do: name
    defp nested(outer, name), do: outer <> "." <> name

    defp raw([:Ecto, :Adapters, :SQL], function) when function in @sql_functions, do: "Ecto.Adapters.SQL.#{function}"
    defp raw([:SQL], function) when function in @sql_functions, do: "SQL.#{function}"
    defp raw([:Postgrex | _rest] = parts, function), do: Name.full(parts) <> "." <> Atom.to_string(function)
    defp raw(_parts, _function), do: nil

    defp issue_for(ctx, meta, trigger) do
      if excluded?(ctx.module, ctx.params.excluded_namespaces) do
        nil
      else
        format_issue(ctx,
          message:
            "`#{trigger}` reaches the database around the mediated repo, so nothing checks or records it. " <>
              "Call the repo with `authorized_by:` instead.",
          trigger: trigger,
          line_no: meta[:line],
          column: meta[:column]
        )
      end
    end

    defp excluded?(nil, _prefixes), do: false
    defp excluded?(module, prefixes), do: Enum.any?(prefixes, &String.starts_with?(module, &1))
  end
end
