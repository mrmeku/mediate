defmodule Mediate.Rbac.Policy.Role do
  @moduledoc "One row of the role table: a role and the actions it permits."

  @enforce_keys [:name, :actions]
  defstruct @enforce_keys

  @typedoc "One role and the actions it permits."
  @type t :: %__MODULE__{name: atom(), actions: [atom()]}
end

defmodule Mediate.Rbac.Policy.Rule do
  @moduledoc """
  One rule of a protected schema: one line of its resource block.

  A grant rule names a grant schema whose rows hold a role for the subject
  on the resource:

  - `grant` is the grant schema
  - `on` is the column of the protected schema the grant's resource
    column names
  - `role_column` is the grant column that holds the role
  - `role` is a role every row holds, when the grant has no role column
  - `through` is the chain of hops a grant rule crosses when the grant
    names a row that is not the protected one

  Each hop is a schema, the column of it the inner set matches, and an
  optional `where:` capture, the hop filter. The capture is a named
  function of no arguments that returns a `dynamic` over the hop's row.
  The next hop, or the protected row's `on` column, matches against the
  hop's primary key.

  A predicate rule runs a function of the subject and the context. It
  returns a `dynamic` over the protected row, or a boolean. `actions`
  names the actions it applies to, every action when nil.
  """

  @enforce_keys [:name, :kind]
  defstruct [:name, :kind, grant: nil, on: nil, role_column: nil, role: nil, through: [], predicate: nil, actions: nil]

  @typedoc "Whether the rule reads grant rows or runs a function."
  @type kind :: :grant | :predicate

  @typedoc "A function of the subject and the context, returning a `dynamic` over the protected row or a boolean."
  @type predicate :: (Mediate.subject(), Mediate.context() -> Ecto.Query.dynamic_expr() | boolean())

  @typedoc "One hop of a grant rule's chain: the schema, the column the inner set matches, and an optional `where:` capture."
  @type hop :: {module(), atom(), [where: (-> Ecto.Query.dynamic_expr())]}

  @typedoc "One rule. The fields a grant rule uses and the fields a predicate rule uses are disjoint."
  @type t :: %__MODULE__{
          name: atom(),
          kind: kind(),
          grant: module() | nil,
          on: atom() | nil,
          role_column: atom() | nil,
          role: atom() | nil,
          through: [hop()],
          predicate: predicate() | nil,
          actions: [atom()] | nil
        }
end

defmodule Mediate.Rbac.Policy.Resource do
  @moduledoc "A protected schema and its rules."

  alias Mediate.Rbac.Policy.Rule

  @enforce_keys [:schema, :rules]
  defstruct @enforce_keys

  @typedoc "A protected schema and every rule of its resource block."
  @type t :: %__MODULE__{schema: module(), rules: [Rule.t()]}
end

defmodule Mediate.Rbac.Policy do
  @moduledoc """
  The policy module: the role table as data and, per protected schema, its
  rules.

      defmodule MyApp.Policy do
        use Mediate.Rbac.Policy, version: "2026.09.1", author: "platform", approval: "ticket 41"

        role :reader, [:read]
        role :editor, [:read, :edit]

        resource MyApp.Folder do
          grant :membership, MyApp.Membership
          predicate :cleared, &MyApp.Predicates.cleared/2
        end
      end

  The rules allow an action on a row when any grant rule holds a role
  that permits it, and when every predicate rule that applies holds. A
  grant rule's schema declares its subject, resource, and role columns
  with `Mediate.Schema.grant/1`. The rule reads them, and takes `on:`,
  `role_column:`, or `role:` when the schema's declaration is not enough.
  `through:` serves a grant that names a row the protected row points at,
  and not the protected row itself. It lists the hops from the protected
  row outward. Each hop is a schema, the column of it the inner set
  matches, and an optional `where:` capture, the hop filter, that narrows
  the hop's rows:

      resource MyApp.Page do
        grant :membership, MyApp.Membership, on: :folder_id, through: [{MyApp.Folder, :id, where: &MyApp.Predicates.open/0}]
      end

  `Mediate.Rbac.Policy.Rule` says what each option means. A predicate is
  a capture of a named function, so the policy stays data a hash can name.
  `actions:` names the actions the predicate rule applies to. `version:`
  defaults to the hash of the policy's text, `author:` and `approval:` to
  `"unrecorded"`.

  The role table is data at compile time. `resources/1` builds the rules
  at each read of the policy, and checks each against the schemas it
  names. Three declarations raise there:

  - a schema without a resource type
  - a grant schema the rule cannot read
  - a predicate that is not a named capture

  So a bad policy fails at boot, when `Mediate.Rbac.release/0` reads it,
  and not on a request. A build at read time keeps the policy module free
  of compile-time dependencies on the schemas and predicates it names. A
  change to any of them recompiles nothing but itself.
  """

  alias Mediate.Rbac.Domain.Rules
  alias Mediate.Rbac.Policy.Resource
  alias Mediate.Rbac.Policy.Role

  @schema NimbleOptions.new!(
            version: [type: {:or, [:string, nil]}, default: nil, doc: "The policy version a decision carries."],
            author: [type: :string, default: "unrecorded", doc: "Who wrote the version."],
            approval: [type: :string, default: "unrecorded", doc: "Who approved it, or where."]
          )

  @typedoc "A module that uses this one."
  @type t :: module()

  @doc "The schema of the options `use` accepts."
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc "Makes the module a policy module. `options_schema/0` has the options."
  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      import Mediate.Rbac.Policy, only: [role: 2, resource: 2, grant: 2, grant: 3, predicate: 2, predicate: 3]

      alias Mediate.Rbac.Policy

      @mediate_policy_options NimbleOptions.validate!(options, Policy.options_schema())
      Module.register_attribute(__MODULE__, :mediate_policy_roles, accumulate: true)
      Module.register_attribute(__MODULE__, :mediate_policy_resources, accumulate: true)
      @before_compile Policy
    end
  end

  @doc "One row of the role table: the role and the actions it permits."
  defmacro role(name, actions) do
    quote bind_quoted: [name: name, actions: actions] do
      @mediate_policy_roles Mediate.Rbac.Policy.__role__(__MODULE__, name, actions)
    end
  end

  @doc "A protected schema and, in the block, its rules."
  defmacro resource(schema, do: block) do
    quote do
      @mediate_policy_rules []
      unquote(block)
      @mediate_policy_resources {unquote(expanded(schema, __CALLER__)), Enum.reverse(@mediate_policy_rules)}
    end
  end

  @doc "A grant rule: the grant schema whose rows hold a role on the protected row."
  defmacro grant(name, grant, options \\ []) do
    rule =
      quote do
        Rules.grant(
          __MODULE__,
          unquote(name),
          unquote(expanded(grant, __CALLER__)),
          unquote(expanded(options, __CALLER__))
        )
      end

    quote do
      @mediate_policy_rules [unquote(Macro.escape(rule)) | @mediate_policy_rules]
    end
  end

  @doc "A predicate rule: a capture of a named function of the subject and the context."
  defmacro predicate(name, fun, options \\ []) do
    rule =
      quote do
        Rules.predicate(
          __MODULE__,
          unquote(name),
          unquote(expanded(fun, __CALLER__)),
          unquote(expanded(options, __CALLER__))
        )
      end

    quote do
      @mediate_policy_rules [unquote(Macro.escape(rule)) | @mediate_policy_rules]
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec __mediate_policy__(:roles | :resources | :options) :: term()
      def __mediate_policy__(:roles), do: Enum.reverse(@mediate_policy_roles)

      def __mediate_policy__(:resources), do: unquote(__MODULE__.__resources__(__CALLER__.module))

      def __mediate_policy__(:options), do: @mediate_policy_options
    end
  end

  @doc "The role table."
  @spec roles(t()) :: [Role.t()]
  def roles(policy) when is_atom(policy), do: policy.__mediate_policy__(:roles)

  @doc "The protected schemas and their rules, built and checked against the schemas they name."
  @spec resources(t()) :: [Resource.t()]
  def resources(policy) when is_atom(policy), do: policy.__mediate_policy__(:resources)

  @doc "Every action some role permits."
  @spec actions(t()) :: [atom()]
  def actions(policy) when is_atom(policy) do
    policy
    |> roles()
    |> Enum.flat_map(& &1.actions)
    |> Enum.uniq()
  end

  @doc "The roles that allow an action."
  @spec roles_for(t(), atom()) :: [atom()]
  def roles_for(policy, action) when is_atom(policy) and is_atom(action) do
    for %Role{name: name, actions: actions} <- roles(policy), action in actions, do: name
  end

  @doc "The role table as data: each role's name to its actions."
  @spec role_table(t()) :: keyword([atom()])
  def role_table(policy) when is_atom(policy) do
    for %Role{name: name, actions: actions} <- roles(policy), do: {name, actions}
  end

  @doc "The modules the rules live in: the policy module and the module of every predicate and hop filter, sorted."
  @spec modules(t()) :: [module()]
  def modules(policy) when is_atom(policy) do
    rules = for %Resource{rules: rules} <- resources(policy), rule <- rules, do: rule
    predicates = for %{kind: :predicate, predicate: fun} <- rules, do: module_of(fun)
    filters = for %{through: hops} <- rules, {_schema, _column, where: fun} <- hops, do: module_of(fun)

    Enum.sort(Enum.uniq([policy | predicates ++ filters]))
  end

  @doc "The `use` options: version, author, approval."
  @spec options(t()) :: keyword()
  def options(policy) when is_atom(policy), do: policy.__mediate_policy__(:options)

  @doc false
  @spec __resources__(module()) :: Macro.t()
  def __resources__(module) when is_atom(module) do
    resources = Enum.reverse(Module.get_attribute(module, :mediate_policy_resources))

    for {schema, rules} <- resources do
      quote do
        Rules.resource(__MODULE__, unquote(schema), unquote(rules))
      end
    end
  end

  @doc false
  @spec __role__(module(), atom(), [atom()]) :: Role.t()
  def __role__(policy, name, actions) when is_atom(policy) and is_atom(name) and is_list(actions) do
    if !Enum.all?(actions, &is_atom/1) do
      raise ArgumentError,
            "#{inspect(policy)}: role #{inspect(name)} lists #{inspect(actions)}; each action must be an atom"
    end

    %Role{name: name, actions: actions}
  end

  defp module_of(fun), do: elem(Function.info(fun, :module), 1)

  # The caller's aliases resolve where the policy names a module, so the
  # rule reads the same when the generated function compiles. The
  # expansion runs under a function environment. An alias expanded in a
  # module body is a compile-time dependency, and the policy must not
  # recompile when a schema or a predicate module changes.
  defp expanded(ast, env) do
    inside = %{env | function: {:__mediate_policy__, 1}}

    Macro.prewalk(ast, fn
      {:__aliases__, _meta, _parts} = alias -> Macro.expand(alias, inside)
      other -> other
    end)
  end
end
