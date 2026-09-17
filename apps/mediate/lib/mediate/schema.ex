defmodule Mediate.Schema.Fact do
  @moduledoc """
  One declared fact column. It holds the kind, the column that names the
  subject, the column that names the object, and the element type of a
  set-valued column. `Mediate.Schema.fact/2` records it, and the seam reads
  it.
  """

  @enforce_keys [:column, :kind, :subject, :object, :element]
  defstruct @enforce_keys

  @type kind :: :subject_attribute | :object_attribute | :relationship

  @type t :: %__MODULE__{
          column: atom(),
          kind: kind(),
          subject: atom() | nil,
          object: atom() | nil,
          element: atom() | nil
        }
end

defmodule Mediate.Schema.Relationship do
  @moduledoc """
  A row that is a grant: the subject column, the object column, and the
  columns that are attributes of the relationship.
  `Mediate.Schema.relationship/1` records it.
  """

  @enforce_keys [:subject, :object, :attributes]
  defstruct @enforce_keys

  @type t :: %__MODULE__{subject: atom(), object: atom(), attributes: [atom()]}
end

defmodule Mediate.Schema do
  @moduledoc """
  Declarations on an Ecto schema. They say:

  - the object type it protects
  - the associations its decision covers
  - what kind of thing its rows are
  - the fact mapping, column by column

  Each macro records its declaration and does nothing else. The seam reads
  them back through `__mediate__/1`.

      defmodule Example.Domain.Visibility do
        use Ecto.Schema
        use Mediate.Schema

        object_type(:visibility)
        audited(:entity)
        fact(:labels, kind: :object_attribute, object: :repository_id, element: :label)
        fact(:restrictions, kind: :object_attribute, object: :repository_id, element: :restriction)
        fact(:releasable_to, kind: :object_attribute, object: :repository_id, element: :country)
        fact(:invited, kind: :relationship, object: :repository_id, element: :user)
      end

  A schema that declares an object type is protected: the seam refuses to
  read or write it without a decision. A schema that declares
  `carries/1` names the associations the root's decision covers. A grant
  row declares `relationship/1` with its subject and object columns.

  `__mediate__/1` answers each declaration:

  - `:object_type`, the declared type or `nil`
  - `:carries`, the carried association names
  - `:kind`, the kind `audited/1` declared or `nil`
  - `:facts`, the `Mediate.Schema.Fact` records in declaration order
  - `:relationship`, the `Mediate.Schema.Relationship` or `nil`

  This file defines every structure it needs, so a schema's compile-time
  dependency on it reaches nothing else.
  """

  alias Mediate.Schema.Fact
  alias Mediate.Schema.Relationship

  @kinds [:user, :group, :role, :entity]

  @fact_schema NimbleOptions.new!(
                 kind: [type: {:in, [:subject_attribute, :object_attribute, :relationship]}, required: true],
                 subject: [
                   type: :atom,
                   doc: "The column that names the subject. A set-valued column's subject is its element."
                 ],
                 object: [type: :atom, doc: "The column that names the object."],
                 element: [
                   type: :atom,
                   doc: "The element type of a set-valued column, which is the type each element refers to."
                 ]
               )

  @relationship_schema NimbleOptions.new!(
                         subject: [type: :atom, required: true],
                         object: [type: :atom, required: true],
                         attributes: [type: {:list, :atom}, default: []]
                       )

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Mediate.Schema, only: [object_type: 1, carries: 1, audited: 1, fact: 2, relationship: 1]

      Module.register_attribute(__MODULE__, :mediate_facts, accumulate: true)
      Module.put_attribute(__MODULE__, :mediate_object_type, nil)
      Module.put_attribute(__MODULE__, :mediate_carries, [])
      Module.put_attribute(__MODULE__, :mediate_kind, nil)
      Module.put_attribute(__MODULE__, :mediate_relationship, nil)
      @before_compile Mediate.Schema
    end
  end

  @doc "Declare the object type this schema's rows are, so a query over it needs a decision."
  defmacro object_type(type) do
    quote bind_quoted: [type: type] do
      Mediate.Schema.__declare_object_type__(__MODULE__, type)
    end
  end

  @doc "Declare the associations the parent's decision covers."
  defmacro carries(associations) do
    quote bind_quoted: [associations: associations] do
      Mediate.Schema.__declare_carries__(__MODULE__, associations)
    end
  end

  @doc "Declare what kind of thing a row of this schema is, which is what makes its writes audited. An audited schema need not declare an object type, and then the seam records its writes and passes them without a decision."
  defmacro audited(kind) do
    quote bind_quoted: [kind: kind] do
      Mediate.Schema.__declare_kind__(__MODULE__, kind)
    end
  end

  @doc "Declare one fact column and how it maps to a fact kind."
  defmacro fact(column, options) do
    quote bind_quoted: [column: column, options: options] do
      Mediate.Schema.__declare_fact__(__MODULE__, column, options)
    end
  end

  @doc "Declare that a row of this schema is a relationship grant."
  defmacro relationship(options) do
    quote bind_quoted: [options: options] do
      Mediate.Schema.__declare_relationship__(__MODULE__, options)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    facts = Enum.reverse(Module.get_attribute(env.module, :mediate_facts))

    quote do
      @doc false
      @spec __mediate__(:object_type | :carries | :kind | :facts | :relationship) :: term()
      def __mediate__(:object_type), do: @mediate_object_type
      def __mediate__(:carries), do: @mediate_carries
      def __mediate__(:kind), do: @mediate_kind
      def __mediate__(:facts), do: unquote(Macro.escape(facts))
      def __mediate__(:relationship), do: @mediate_relationship
    end
  end

  @doc "The object type a module declares, or `nil` for a module that declares none or is not a schema."
  @spec object_type_of(term()) :: atom() | nil
  def object_type_of(module) do
    if declares?(module), do: module.__mediate__(:object_type)
  end

  @doc "The associations a module's decision covers, or `[]` where it declares none."
  @spec carries_of(term()) :: [atom()]
  def carries_of(module) do
    if declares?(module), do: module.__mediate__(:carries), else: []
  end

  @doc "What kind of thing a module's rows are, or `nil` for a module that declares none."
  @spec kind_of(term()) :: atom() | nil
  def kind_of(module) do
    if declares?(module), do: module.__mediate__(:kind)
  end

  @doc "A row's primary key: the value of its one key column, or a map of the columns where it has several."
  @spec id_of(struct()) :: term()
  def id_of(%{__struct__: schema} = row) do
    case schema.__schema__(:primary_key) do
      [key] -> Map.get(row, key)
      keys -> Map.new(keys, &{&1, Map.get(row, &1)})
    end
  end

  @doc "Whether the seam audits a module's writes, which is whether it declares what kind of thing its rows are."
  @spec audited?(term()) :: boolean()
  def audited?(module), do: kind_of(module) != nil

  @doc "The fact columns a module declares, in declaration order, or `[]` where it declares none."
  @spec facts_of(term()) :: [Fact.t()]
  def facts_of(module) do
    if declares?(module), do: module.__mediate__(:facts), else: []
  end

  @doc """
  The columns a module declares as facts: its fact columns and the columns
  of its relationship, each once, in declaration order.
  """
  @spec fact_columns(term()) :: [atom()]
  def fact_columns(module) do
    columns = Enum.map(facts_of(module), & &1.column) ++ relationship_columns(relationship_of(module))

    Enum.uniq(columns)
  end

  @doc "The relationship a module's rows are, or `nil`."
  @spec relationship_of(term()) :: Relationship.t() | nil
  def relationship_of(module) do
    if declares?(module), do: module.__mediate__(:relationship)
  end

  @doc "Whether a module carries fact declarations: a fact column or a relationship."
  @spec fact_schema?(term()) :: boolean()
  def fact_schema?(module), do: facts_of(module) != [] or relationship_of(module) != nil

  @doc "Whether a module used `Mediate.Schema`."
  @spec declares?(term()) :: boolean()
  def declares?(module) when is_atom(module) and not is_nil(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__mediate__, 1)
  end

  def declares?(_other), do: false

  @doc false
  @spec __declare_object_type__(module(), atom()) :: :ok
  def __declare_object_type__(module, type) when is_atom(module) and is_atom(type) and not is_nil(type) do
    case Module.get_attribute(module, :mediate_object_type) do
      nil -> Module.put_attribute(module, :mediate_object_type, type)
      other -> raise ArgumentError, "#{inspect(module)} already declares object_type #{inspect(other)}"
    end
  end

  @doc false
  @spec __declare_carries__(module(), [atom()]) :: :ok
  def __declare_carries__(module, associations) when is_atom(module) and is_list(associations) do
    if !Enum.all?(associations, &is_atom/1) do
      raise ArgumentError, "carries expects a list of association names, got: #{inspect(associations)}"
    end

    declared = Module.get_attribute(module, :mediate_carries)

    case Enum.filter(associations, &(&1 in declared)) do
      [] -> Module.put_attribute(module, :mediate_carries, declared ++ associations)
      repeated -> raise ArgumentError, "#{inspect(module)} already carries #{inspect(repeated)}"
    end
  end

  @doc false
  @spec __declare_kind__(module(), atom()) :: :ok
  def __declare_kind__(module, kind) when is_atom(module) do
    if kind not in @kinds do
      raise ArgumentError, "audited expects one of #{inspect(@kinds)}, got: #{inspect(kind)}"
    end

    case Module.get_attribute(module, :mediate_kind) do
      nil -> Module.put_attribute(module, :mediate_kind, kind)
      other -> raise ArgumentError, "#{inspect(module)} is already audited as #{inspect(other)}"
    end
  end

  @doc false
  @spec __declare_fact__(module(), atom(), keyword()) :: :ok
  def __declare_fact__(module, column, options) when is_atom(module) and is_atom(column) and is_list(options) do
    options = NimbleOptions.validate!(options, @fact_schema)

    fact = %Fact{
      column: column,
      kind: options[:kind],
      subject: options[:subject],
      object: options[:object],
      element: options[:element]
    }

    Module.put_attribute(module, :mediate_facts, fact)
  end

  @doc false
  @spec __declare_relationship__(module(), keyword()) :: :ok
  def __declare_relationship__(module, options) when is_atom(module) and is_list(options) do
    options = NimbleOptions.validate!(options, @relationship_schema)

    case Module.get_attribute(module, :mediate_relationship) do
      nil ->
        relationship = %Relationship{
          subject: options[:subject],
          object: options[:object],
          attributes: options[:attributes]
        }

        Module.put_attribute(module, :mediate_relationship, relationship)

      %Relationship{} ->
        raise ArgumentError, "#{inspect(module)} already declares a relationship"
    end
  end

  defp relationship_columns(nil), do: []

  defp relationship_columns(%Relationship{subject: subject, object: object, attributes: attributes}),
    do: [subject, object | attributes]
end
