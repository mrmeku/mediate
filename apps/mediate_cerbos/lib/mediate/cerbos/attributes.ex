defmodule Mediate.Cerbos.Attributes do
  @moduledoc """
  The declarations that say what the adapter can send the sidecar and what
  a query plan can compile over.

      defmodule MyApp.Attributes do
        use Mediate.Cerbos.Attributes

        principal :user, schema: MyApp.Account do
          attribute :clearance, column: :clearance
        end

        resource :folder, schema: MyApp.Folder do
          attribute :member_roles, subquery: &MyApp.Memberships.folder_roles_for/2
        end

        environment do
          fact :reauthenticated_at
        end
      end

  A `principal` block names a subject kind and the schema whose row is the
  subject. A `resource` block names an object type and the schema whose
  rows are the objects. Inside either, `attribute/2` maps a name the
  policies use to a column or to a subquery (`Mediate.Cerbos.Attribute`).

  An `environment` block names the request-time facts a policy can read.
  They come from the caller and not from a row. They reach the policies as
  the principal attribute `Mediate.Cerbos.Attribute.reserved/0`, beside the
  moment the port stamped the request with. The moment travels whether the
  block declares anything or not. A fact the caller did not supply goes as
  `nil`, and never drops out.

  Two rules follow from the declarations, and they are why the declarations
  exist. The adapter sends the sidecar the declared attributes, the
  declared request-time facts, and nothing else. So a policy cannot depend
  on a value no one declared. The query plan the sidecar returns compiles
  over declared attributes alone. So this adapter refuses to turn a plan
  that reads anything else into a query. The columns behind the
  declarations must also be facts the application declares, which
  `Mediate.Cerbos.Coverage` checks.

  A module that used this one answers `__mediate_cerbos__/1`. The functions
  here read the declarations through it, so a declaration module carries
  the declarations and nothing more.
  """

  alias Mediate.Cerbos.Attribute

  @kind_schema NimbleOptions.new!(
                 schema: [
                   type: :atom,
                   required: true,
                   doc: "The Ecto schema whose rows hold the kind's attributes."
                 ]
               )

  @typedoc "A module that used this one."
  @type t :: module()

  @typedoc "A declared kind: the side it is on, its name, and the schema behind it."
  @type kind :: {:principal | :resource, atom(), module()}

  @doc false
  defmacro __using__(_options) do
    quote do
      import Mediate.Cerbos.Attributes, only: [attribute: 2, environment: 1, principal: 3, resource: 3]

      Module.register_attribute(__MODULE__, :mediate_cerbos_kinds, accumulate: true)
      Module.register_attribute(__MODULE__, :mediate_cerbos_declared, accumulate: true)
      Module.register_attribute(__MODULE__, :mediate_cerbos_facts, accumulate: true)
      Module.put_attribute(__MODULE__, :mediate_cerbos_current, nil)

      @before_compile Mediate.Cerbos.Attributes
    end
  end

  @doc "Declares the attributes of a subject kind. Their values come from the row the subject's id names."
  defmacro principal(kind, options, do: block), do: kind(:principal, kind, options, block, __CALLER__)

  @doc "Declares the attributes of an object type. Their values come from the rows the objects name."
  defmacro resource(kind, options, do: block), do: kind(:resource, kind, options, block, __CALLER__)

  @doc """
  Declares the request-time facts the policies can read. Each is
  `fact :name`, where the name is the key the caller's facts carry.
  """
  defmacro environment(do: block) do
    {:__block__, [], Enum.map(fact_names(block), &quote(do: @mediate_cerbos_facts(unquote(&1))))}
  end

  @doc "Declares one attribute of the block it stands in, with `column:` or `subquery:`."
  defmacro attribute(name, options) do
    quote do
      @mediate_cerbos_declared {@mediate_cerbos_current, unquote(name)}

      @doc false
      def __attribute__(@mediate_cerbos_current, unquote(name)) do
        Attribute.new!(unquote(name), unquote(options))
      end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec __mediate_cerbos__(:kinds | :declared | :facts) :: term()
      def __mediate_cerbos__(:kinds), do: Enum.reverse(@mediate_cerbos_kinds)
      def __mediate_cerbos__(:declared), do: Enum.reverse(@mediate_cerbos_declared)
      def __mediate_cerbos__(:facts), do: Enum.reverse(@mediate_cerbos_facts)
    end
  end

  @doc "The schema of the options a `principal` or `resource` block takes."
  @spec kind_options_schema() :: NimbleOptions.t()
  def kind_options_schema, do: @kind_schema

  @doc "Whether the module is a declaration module of this adapter."
  @spec declares?(module()) :: boolean()
  def declares?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__mediate_cerbos__, 1)
  end

  @doc "The request-time facts declared, in declaration order."
  @spec facts(t()) :: [atom()]
  def facts(module) when is_atom(module), do: module.__mediate_cerbos__(:facts)

  @doc "The subject kinds and object types declared, with the side each is on and its schema."
  @spec kinds(t()) :: [kind()]
  def kinds(module) when is_atom(module), do: module.__mediate_cerbos__(:kinds)

  @doc "The subject kinds declared."
  @spec principals(t()) :: [atom()]
  def principals(module) when is_atom(module), do: for({:principal, kind, _schema} <- kinds(module), do: kind)

  @doc "The object types declared."
  @spec resources(t()) :: [atom()]
  def resources(module) when is_atom(module), do: for({:resource, kind, _schema} <- kinds(module), do: kind)

  @doc "Whether the module declares the kind, on either side."
  @spec declared?(t(), atom()) :: boolean()
  def declared?(module, kind) when is_atom(module) and is_atom(kind) do
    Enum.any?(kinds(module), fn {_side, name, _schema} -> name == kind end)
  end

  @doc "The schema that holds a kind's attributes, or `nil` for a kind no declaration names."
  @spec schema_of(t(), atom()) :: module() | nil
  def schema_of(module, kind) when is_atom(module) and is_atom(kind) do
    Enum.find_value(kinds(module), fn {_side, name, schema} -> if name == kind, do: schema end)
  end

  @doc "The attribute declarations of a kind, in declaration order."
  @spec attributes_of(t(), atom()) :: [Attribute.t()]
  def attributes_of(module, kind) when is_atom(module) and is_atom(kind) do
    for {declared, name} <- module.__mediate_cerbos__(:declared),
        declared == kind,
        do: module.__attribute__(kind, name)
  end

  @doc "Every declaration of the module, both sides, as the pairs `attributes_of/2` answers."
  @spec all(t()) :: [{atom(), Attribute.t()}]
  def all(module) when is_atom(module) do
    for {_side, kind, _schema} <- kinds(module), attribute <- attributes_of(module, kind), do: {kind, attribute}
  end

  @doc "The declaration of one attribute of one kind, or `nil`."
  @spec find(t(), atom(), atom()) :: Attribute.t() | nil
  def find(module, kind, name) when is_atom(module) and is_atom(kind) and is_atom(name) do
    Enum.find(attributes_of(module, kind), &(&1.name == name))
  end

  # This reads the block where it stands, and not through a macro per fact.
  # So `fact_name/1` refuses an expression that is no fact declaration.
  defp fact_names({:__block__, _meta, declarations}), do: Enum.map(declarations, &fact_name/1)
  defp fact_names(declaration), do: [fact_name(declaration)]

  defp fact_name({:fact, _meta, [name]}) when is_atom(name), do: name

  defp fact_name(other) do
    raise ArgumentError, "an environment block declares a fact with `fact :name`, not #{Macro.to_string(other)}"
  end

  defp kind(side, kind, options, block, caller) do
    quote do
      options = NimbleOptions.validate!(unquote(expanded(options, caller)), unquote(__MODULE__).kind_options_schema())
      @mediate_cerbos_kinds {unquote(side), unquote(kind), options[:schema]}
      @mediate_cerbos_current unquote(kind)
      unquote(block)
      @mediate_cerbos_current nil
    end
  end

  # This expands the caller's aliases where a declaration names a schema,
  # under a function environment. An alias expanded in a module body is a
  # compile-time dependency. A declaration must not recompile when the
  # schema behind it changes.
  defp expanded(ast, env) do
    inside = %{env | function: {:__mediate_cerbos__, 1}}

    Macro.prewalk(ast, fn
      {:__aliases__, _meta, _parts} = alias -> Macro.expand(alias, inside)
      other -> other
    end)
  end
end
