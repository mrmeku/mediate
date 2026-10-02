defmodule Mediate.Cerbos.Declarations do
  @moduledoc """
  What the engine sends the server, and what a plan compiles over.

      defmodule MyApp.Declarations do
        use Mediate.Cerbos.Declarations

        principal :user, schema: MyApp.Account do
          attribute :clearance, column: :clearance
        end

        resource :folder, schema: MyApp.Folder do
          attribute :member_roles, subquery: &MyApp.Memberships.folder_roles/2
        end

        context do
          fact :reauthenticated_at
        end
      end

  A `principal` block names a subject kind and the schema whose row is the
  subject. A `resource` block names a resource type and the schema whose
  rows are the resources. The two sides are separate, so a deployment may
  declare `principal :user` and `resource :user` both, and every read here
  takes the block as `{:principal, kind}` or `{:resource, type}`. Inside
  either block, `attribute/2` maps a name the policies read to a column or
  to a subquery (`Mediate.Cerbos.Attribute`).

  A `context` block names the context facts a policy can read. They come
  from the caller and not from a row. They reach the policies as the
  principal attribute `context`, beside `now`, the moment the library
  stamped the request with. So a policy reads
  `request.principal.attr.context.now`. The moment travels whether the
  block declares anything or not. A fact the caller did not supply goes as
  `nil`, and never drops out.

  Two rules follow from the declarations, and they are why the
  declarations exist. The engine sends the server the declared attributes,
  the context facts, and nothing else. So a policy cannot read a value no
  one declared. The plan the server answers compiles over declared
  attributes alone. So the compiler refuses a plan that reads anything
  else. The columns behind the declarations must also be facts the
  deployment declares, which `Mediate.Cerbos.Facts` checks.

  A module that used this one answers `__mediate_cerbos__/1`. The reads
  here go through it, so the module carries the declarations and nothing
  more.
  """

  alias Mediate.Cerbos.Attribute

  @block_schema NimbleOptions.new!(
                  schema: [
                    type: :atom,
                    required: true,
                    doc: "The Ecto schema whose rows hold the block's attributes."
                  ]
                )

  @typedoc "A module that used this one."
  @type t :: module()

  @typedoc "A block: the side it is on, and the subject kind or resource type it names."
  @type block :: {:principal | :resource, atom()}

  @typedoc "A declared block with the schema behind it."
  @type declared :: {:principal | :resource, atom(), module()}

  @doc false
  defmacro __using__(_options) do
    quote do
      import Mediate.Cerbos.Declarations, only: [attribute: 2, context: 1, principal: 3, resource: 3]

      Module.register_attribute(__MODULE__, :mediate_cerbos_blocks, accumulate: true)
      Module.register_attribute(__MODULE__, :mediate_cerbos_attributes, accumulate: true)
      Module.register_attribute(__MODULE__, :mediate_cerbos_facts, accumulate: true)
      Module.put_attribute(__MODULE__, :mediate_cerbos_block, nil)

      @before_compile Mediate.Cerbos.Declarations
    end
  end

  @doc "Declares the attributes of a subject kind. Their values come from the row the subject's id names."
  defmacro principal(kind, options, do: block), do: declared(:principal, kind, options, block, __CALLER__)

  @doc "Declares the attributes of a resource type. Their values come from the rows the resources name."
  defmacro resource(type, options, do: block), do: declared(:resource, type, options, block, __CALLER__)

  @doc """
  Declares the context facts the policies can read. Each is `fact :name`,
  where the name is the key the caller's context carries.
  """
  defmacro context(do: block) do
    {:__block__, [], Enum.map(fact_names(block), &quote(do: @mediate_cerbos_facts(unquote(&1))))}
  end

  @doc "Declares one attribute of the block it stands in, with `column:` or `subquery:`."
  defmacro attribute(name, options) do
    quote do
      @mediate_cerbos_attributes {@mediate_cerbos_block, unquote(name)}

      @doc false
      def __attribute__(@mediate_cerbos_block, unquote(name)) do
        Attribute.new!(unquote(name), unquote(options))
      end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      @spec __mediate_cerbos__(:blocks | :attributes | :facts) :: term()
      def __mediate_cerbos__(:blocks), do: Enum.reverse(@mediate_cerbos_blocks)
      def __mediate_cerbos__(:attributes), do: Enum.reverse(@mediate_cerbos_attributes)
      def __mediate_cerbos__(:facts), do: Enum.reverse(@mediate_cerbos_facts)
    end
  end

  @doc "The schema of the options a `principal` or `resource` block takes."
  @spec block_options_schema() :: NimbleOptions.t()
  def block_options_schema, do: @block_schema

  @doc "Whether the module used this one."
  @spec declares?(module()) :: boolean()
  def declares?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__mediate_cerbos__, 1)
  end

  @doc "The blocks declared, with the side each is on and its schema, in declaration order."
  @spec blocks(t()) :: [declared()]
  def blocks(module) when is_atom(module), do: module.__mediate_cerbos__(:blocks)

  @doc "The subject kinds declared."
  @spec principals(t()) :: [atom()]
  def principals(module) when is_atom(module), do: for({:principal, kind, _schema} <- blocks(module), do: kind)

  @doc "The resource types declared."
  @spec resources(t()) :: [atom()]
  def resources(module) when is_atom(module), do: for({:resource, type, _schema} <- blocks(module), do: type)

  @doc "The context facts declared, in declaration order."
  @spec facts(t()) :: [atom()]
  def facts(module) when is_atom(module), do: module.__mediate_cerbos__(:facts)

  @doc "Every attribute of the module with its block, in declaration order."
  @spec attributes(t()) :: [{block(), Attribute.t()}]
  def attributes(module) when is_atom(module) do
    for {block, name} <- module.__mediate_cerbos__(:attributes), do: {block, module.__attribute__(block, name)}
  end

  @doc "Whether the module declares the block."
  @spec names?(t(), block()) :: boolean()
  def names?(module, {side, name}) when is_atom(module) and is_atom(side) and is_atom(name) do
    Enum.any?(blocks(module), fn {declared_side, declared_name, _schema} ->
      {declared_side, declared_name} == {side, name}
    end)
  end

  @doc "The schema that holds a block's attributes, or `nil` for a block no declaration names."
  @spec schema_of(t(), block()) :: module() | nil
  def schema_of(module, {side, name}) when is_atom(module) and is_atom(side) and is_atom(name) do
    Enum.find_value(blocks(module), fn {declared_side, declared_name, schema} ->
      if {declared_side, declared_name} == {side, name}, do: schema
    end)
  end

  @doc "The attributes of a block, in declaration order."
  @spec attributes_of(t(), block()) :: [Attribute.t()]
  def attributes_of(module, {side, name} = block) when is_atom(module) and is_atom(side) and is_atom(name) do
    for {declared, attribute_name} <- module.__mediate_cerbos__(:attributes),
        declared == block,
        do: module.__attribute__(block, attribute_name)
  end

  @doc "One attribute of a block by its name, or `nil`."
  @spec find(t(), block(), atom()) :: Attribute.t() | nil
  def find(module, {_side, _name} = block, name) when is_atom(module) and is_atom(name) do
    Enum.find(attributes_of(module, block), &(&1.name == name))
  end

  # This reads the block where it stands, and not through a macro per fact.
  # So `fact_name/1` refuses an expression that is no fact declaration.
  defp fact_names({:__block__, _meta, declarations}), do: Enum.map(declarations, &fact_name/1)
  defp fact_names(declaration), do: [fact_name(declaration)]

  defp fact_name({:fact, _meta, [name]}) when is_atom(name), do: name

  defp fact_name(other) do
    raise ArgumentError, "a context block declares a fact with `fact :name`, not #{Macro.to_string(other)}"
  end

  defp declared(side, name, options, block, caller) do
    quote do
      options = NimbleOptions.validate!(unquote(expanded(options, caller)), unquote(__MODULE__).block_options_schema())
      @mediate_cerbos_blocks {unquote(side), unquote(name), options[:schema]}
      @mediate_cerbos_block {unquote(side), unquote(name)}
      unquote(block)
      @mediate_cerbos_block nil
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
