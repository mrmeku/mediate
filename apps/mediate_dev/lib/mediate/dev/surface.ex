defmodule Mediate.Dev.Surface do
  @moduledoc """
  The mechanism behind `mix mediate.surface`. It reads one application and
  answers the names an adopter can write: every public module, every public
  function with its arity and its spec, every struct field, every atom a
  public type offers as a choice, every option key, and every key of a
  telemetry event. The naming test of `mediate` holds each name to a row of
  `docs/naming.md`.

  The modules, functions, specs, fields, and atoms come from the compiled
  code, through the docs chunk and the typespecs, so a module with
  `@moduledoc false` and a function with `@doc false` stay out as ExDoc
  leaves them out. The option keys and the event keys come from the syntax
  tree of every module's source, hidden modules among them, because a
  `NimbleOptions` schema and an event payload are literals in the source
  that no compiled module lists, and a key is public whichever module
  holds the literal.
  """

  use Boundary, top_level?: true, deps: [NimbleOptions]

  @schema NimbleOptions.new!(
            modules: [
              type: {:list, :atom},
              doc: "The modules to read, each loaded. The application's own modules under `lib` when absent."
            ]
          )

  @enforce_keys [:app, :modules, :functions, :fields, :atoms, :options, :events]
  defstruct @enforce_keys

  @typedoc "One public function: its module, name, arity, and spec as text, or `nil` when it has none."
  @type function_entry :: {module(), atom(), non_neg_integer(), String.t() | nil}

  @typedoc "The atoms one public type offers as a choice, under the type's name."
  @type choice :: {module(), atom(), [atom()]}

  @typedoc "The keys of one event, its measurements and its payload together, under the event's name."
  @type event :: {module(), [atom()], [atom()]}

  @typedoc "The surface of one application."
  @type t :: %__MODULE__{
          app: atom(),
          modules: [module()],
          functions: [function_entry()],
          fields: [{module(), [atom()]}],
          atoms: [choice()],
          options: [{module(), [atom()]}],
          events: [event()]
        }

  @doc "The surface of a loaded application, every list sorted. Options: #{NimbleOptions.docs(@schema)}"
  @spec of(atom(), keyword()) :: t()
  def of(app, options \\ []) when is_atom(app) do
    options = NimbleOptions.validate!(options, @schema)
    :ok = load(app)
    all = Enum.sort(options[:modules] || shipped(app))
    read(app, all, Enum.filter(all, &public?/1))
  end

  @doc "The surface as lines of text, one name per line, as the task prints it."
  @spec to_lines(t()) :: [String.t()]
  def to_lines(%__MODULE__{} = surface) do
    Enum.flat_map(@enforce_keys -- [:app], &lines(&1, Map.fetch!(surface, &1)))
  end

  defp read(app, all, public) do
    %__MODULE__{
      app: app,
      modules: public,
      functions: Enum.flat_map(public, &functions/1),
      fields: each(public, &fields/1),
      atoms: Enum.flat_map(public, &choices/1),
      options: each(all, &option_keys/1),
      events: Enum.flat_map(all, &events/1)
    }
  end

  defp lines(:modules, modules), do: Enum.map(modules, &"module #{inspect(&1)}")

  defp lines(:functions, functions) do
    Enum.map(functions, fn {module, name, arity, spec} ->
      "function #{inspect(module)}.#{name}/#{arity}" <> if(spec, do: " :: #{spec}", else: "")
    end)
  end

  defp lines(:fields, fields) do
    Enum.flat_map(fields, fn {module, names} -> Enum.map(names, &"field #{inspect(module)}.#{&1}") end)
  end

  defp lines(:atoms, atoms) do
    Enum.flat_map(atoms, fn {module, type, names} ->
      Enum.map(names, &"atom #{inspect(module)}.#{type}() #{inspect(&1)}")
    end)
  end

  defp lines(:options, options) do
    Enum.flat_map(options, fn {module, keys} -> Enum.map(keys, &"option #{inspect(module)} #{&1}:") end)
  end

  defp lines(:events, events) do
    Enum.flat_map(events, fn {_module, event, keys} -> Enum.map(keys, &"event #{inspect(event)} #{&1}") end)
  end

  # Each module with what the function answers for it, leaving out the
  # modules it answers nothing for.
  defp each(modules, fun) do
    for module <- modules, answer = fun.(module), answer != [], do: {module, answer}
  end

  defp load(app) do
    case Application.load(app) do
      :ok -> :ok
      {:error, {:already_loaded, ^app}} -> :ok
    end
  end

  # A test run compiles `test/support` into the application too, and those
  # modules are nobody's surface. What ships is what `lib` holds.
  defp shipped(app) do
    app
    |> Application.spec(:modules)
    |> Enum.filter(&shipped?/1)
  end

  defp shipped?(module) do
    Code.ensure_loaded!(module)

    case module.module_info(:compile)[:source] do
      nil -> false
      path -> "lib" in Path.split(List.to_string(path))
    end
  end

  # A module is public when ExDoc would list it: it has a docs chunk and
  # its moduledoc is not hidden.
  defp public?(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _anno, _language, _format, moduledoc, _meta, _docs} -> moduledoc != :hidden
      {:error, _reason} -> false
    end
  end

  defp functions(module) do
    {:docs_v1, _anno, _language, _format, _moduledoc, _meta, docs} = Code.fetch_docs(module)
    specs = specs(module)

    for_result =
      for {{kind, name, arity}, _anno, _signature, doc, _meta} <- docs,
          kind in [:function, :macro],
          doc != :hidden do
        {module, name, arity, specs[{name, arity}]}
      end

    Enum.sort(for_result)
  end

  defp specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        Map.new(specs, fn {{name, arity}, [spec | _rest]} -> {{name, arity}, printed(name, spec)} end)

      :error ->
        %{}
    end
  end

  defp printed(name, spec) do
    name
    |> Code.Typespec.spec_to_quoted(spec)
    |> Macro.to_string()
    |> one_line()
  end

  # `Macro.to_string/1` breaks a long spec over lines, and a line of the
  # printout is one name. The break leaves a space inside a bracket, which
  # the join removes.
  defp one_line(text) do
    text
    |> String.split("\n")
    |> Enum.map_join(" ", &String.trim/1)
    |> String.replace(~r/([(\[{]) /, "\\1")
    |> String.replace(~r/ ([)\]}])/, "\\1")
  end

  defp fields(module) do
    if function_exported?(module, :__struct__, 0) do
      module.__struct__()
      |> Map.keys()
      |> Enum.reject(&String.starts_with?(Atom.to_string(&1), "__"))
      |> Enum.sort()
    else
      []
    end
  end

  # Every union of two or more literal atoms inside a public type, so a
  # closed list such as `:allow | :deny` surfaces whether the type is the
  # list itself or a struct whose field offers it.
  defp choices(module) do
    case Code.Typespec.fetch_types(module) do
      {:ok, types} ->
        for_result =
          for {:type, {name, definition, _args}} <- types,
              atoms = union_atoms(definition),
              atoms != [] do
            {module, name, atoms}
          end

        Enum.sort(for_result)

      :error ->
        []
    end
  end

  defp union_atoms(definition) do
    {_definition, found} =
      Macro.prewalk(definition, [], fn
        {:type, _line, :union, members} = node, found ->
          atoms = for {:atom, _line, atom} <- members, is_atom(atom), atom not in [nil, true, false], do: atom
          {node, if(length(atoms) >= 2, do: atoms ++ found, else: found)}

        node, found ->
          {node, found}
      end)

    found
    |> Enum.uniq()
    |> Enum.sort()
  end

  # The body of this module's own `defmodule`, so a file that defines
  # three modules attributes each literal to the module that holds it. A
  # module compiled on another machine, as Elixir's own are, has no source
  # here and so has no literals.
  defp source(module) do
    case File.read(List.to_string(module.module_info(:compile)[:source])) do
      {:ok, text} -> body_of(Code.string_to_quoted!(text), module)
      {:error, _reason} -> nil
    end
  end

  defp body_of(ast, module) do
    parts = Enum.map(Module.split(module), &String.to_atom/1)

    {_ast, found} =
      Macro.prewalk(ast, nil, fn
        {:defmodule, _meta, [{:__aliases__, _alias, ^parts}, [do: body]]} = node, nil -> {node, body}
        node, found -> {node, found}
      end)

    found
  end

  # The keys of every `NimbleOptions.new!` literal in the module's source,
  # the keys under a `keys:` of one, and the atoms of an `{:in, list}` type.
  defp option_keys(module) do
    case source(module) do
      nil -> []
      ast -> unique(Enum.flat_map(schemas(ast), &keys_of/1))
    end
  end

  defp unique(list) do
    list
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp schemas(ast) do
    {_ast, found} =
      Macro.prewalk(ast, [], fn
        {{:., _dot, [{:__aliases__, _alias, [:NimbleOptions]}, :new!]}, _call, [schema]} = node, found ->
          {node, [schema | found]}

        node, found ->
          {node, found}
      end)

    found
  end

  defp keys_of(schema) when is_list(schema) do
    Enum.flat_map(schema, fn
      {key, spec} when is_atom(key) and is_list(spec) ->
        [key] ++ keys_of(Keyword.get(spec, :keys, [])) ++ in_atoms(Keyword.get(spec, :type))

      {key, _spec} when is_atom(key) ->
        [key]

      _other ->
        []
    end)
  end

  defp keys_of(_other), do: []

  defp in_atoms({:in, atoms}) when is_list(atoms), do: Enum.filter(atoms, &is_atom/1)
  defp in_atoms(_type), do: []

  # Every `:telemetry.execute/3` in the module's source, with the keys of
  # each map literal in the function that calls it and in any local
  # function the payload argument calls, and the event name resolved
  # through the module attribute that holds it.
  defp events(module) do
    case source(module) do
      nil -> []
      ast -> Enum.sort(for {event, keys} <- executes(ast), do: {module, event, keys})
    end
  end

  defp executes(ast) do
    attributes = attributes(ast)
    definitions = definitions(ast)

    for_result =
      for {_kind, _meta, [_head, [do: body]]} <- definitions,
          {event, measurements, payload} <- calls(body) do
        {resolve(event, attributes), keys_around(definitions, [measurements, payload, body], payload)}
      end

    Enum.uniq(for_result)
  end

  # The keys of every map literal in the bodies given and in the local
  # function the payload argument calls, when it calls one.
  defp keys_around(definitions, bodies, payload) do
    callee =
      case payload do
        {name, _meta, args} when is_atom(name) and is_list(args) -> name
        _other -> nil
      end

    bodies
    |> Kernel.++(bodies_of(definitions, callee))
    |> Enum.flat_map(&map_keys/1)
    |> unique()
  end

  defp calls(body) do
    {_body, found} =
      Macro.prewalk(body, [], fn
        {{:., _dot, [:telemetry, :execute]}, _call, [event, measurements, payload]} = node, found ->
          {node, [{event, measurements, payload} | found]}

        node, found ->
          {node, found}
      end)

    found
  end

  defp definitions(ast) do
    {_ast, found} =
      Macro.prewalk(ast, [], fn
        {kind, _meta, [_head, [do: _body]]} = node, found when kind in [:def, :defp] -> {node, [node | found]}
        node, found -> {node, found}
      end)

    Enum.reverse(found)
  end

  defp bodies_of(_definitions, nil), do: []

  defp bodies_of(definitions, name) do
    for {_kind, _meta, [head, [do: body]]} <- definitions, head_name(head) == name, do: body
  end

  defp head_name({:when, _meta, [head | _guards]}), do: head_name(head)
  defp head_name({name, _meta, _args}) when is_atom(name), do: name
  defp head_name(_other), do: nil

  defp attributes(ast) do
    {_ast, found} =
      Macro.prewalk(ast, %{}, fn
        {:@, _meta, [{name, _name_meta, [value]}]} = node, found when is_atom(name) -> {node, Map.put(found, name, value)}
        node, found -> {node, found}
      end)

    found
  end

  defp resolve({:@, _meta, [{name, _name_meta, nil}]}, attributes), do: resolve(Map.get(attributes, name), attributes)
  defp resolve(event, _attributes) when is_list(event), do: Enum.filter(event, &is_atom/1)
  defp resolve(_event, _attributes), do: []

  defp map_keys(ast) do
    {_ast, found} =
      Macro.prewalk(ast, [], fn
        {:%{}, _meta, pairs} = node, found when is_list(pairs) ->
          {node,
           Enum.reduce(pairs, found, fn
             {key, _value}, acc when is_atom(key) -> [key | acc]
             _pair, acc -> acc
           end)}

        node, found ->
          {node, found}
      end)

    found
  end
end
