defmodule Mediate.Schema.Fact do
  @moduledoc """
  One declared fact column. It holds whose fact it is, the column that
  names the subject, the column that names the resource, and the element
  type of a set-valued column. `Mediate.Schema.fact/2` records it, and the
  mediated repo reads it.
  """

  @enforce_keys [:column, :about, :subject, :resource, :element]
  defstruct @enforce_keys

  @typedoc "Whose fact the column is: the subject's, the resource's, or the grant's."
  @type about :: :subject | :resource | :grant

  @typedoc "One fact declaration, as `Mediate.Schema.fact/2` records it."
  @type t :: %__MODULE__{
          column: atom(),
          about: about(),
          subject: atom() | nil,
          resource: atom() | nil,
          element: atom() | nil
        }
end

defmodule Mediate.Schema.Grant do
  @moduledoc """
  A row that is a grant: the subject column, the resource column, and the
  columns that are attributes of the grant. `Mediate.Schema.grant/1`
  records it.
  """

  @enforce_keys [:subject, :resource, :attributes]
  defstruct @enforce_keys

  @typedoc "One grant declaration, as `Mediate.Schema.grant/1` records it."
  @type t :: %__MODULE__{subject: atom(), resource: atom(), attributes: [atom()]}
end

defmodule Mediate.Schema do
  @moduledoc """
  Declarations on an Ecto schema. They say:

  - the resource type it protects
  - the associations its decision covers
  - that its rows are identities, and of which kind
  - the fact mapping, column by column

  Each macro records its declaration and does nothing else. The mediated
  repo reads them back through `__mediate__/1`.

      defmodule Example.Domain.Visibility do
        use Ecto.Schema
        use Mediate.Schema

        resource_type(:visibility)
        identity(:other)
        fact(:labels, about: :resource, resource: :repository_id, element: :label)
        fact(:restrictions, about: :resource, resource: :repository_id, element: :restriction)
        fact(:releasable_to, about: :resource, resource: :repository_id, element: :country)
        fact(:invited, about: :grant, resource: :repository_id, element: :account)
      end

  A schema that declares a resource type is protected: the mediated repo
  refuses to read or write it without a decision. A schema that declares
  `covers/1` names the associations the root's decision covers. A grant
  row declares `grant/1` with its subject and resource columns.

  `__mediate__/1` answers each declaration:

  - `:resource_type`, the declared type or `nil`
  - `:covers`, the covered association names
  - `:identity`, the kind `identity/1` declared or `nil`
  - `:facts`, the `Mediate.Schema.Fact` records in declaration order
  - `:grant`, the `Mediate.Schema.Grant` or `nil`

  This file defines every structure it needs, so a schema's compile-time
  dependency on it reaches nothing else.
  """

  alias Mediate.Schema.Fact
  alias Mediate.Schema.Grant

  @identities [:account, :group, :role, :other]

  @fact_schema NimbleOptions.new!(
                 about: [type: {:in, [:subject, :resource, :grant]}, required: true],
                 subject: [
                   type: :atom,
                   doc: "The column that names the subject. A set-valued column's subject is its element."
                 ],
                 resource: [type: :atom, doc: "The column that names the resource."],
                 element: [
                   type: :atom,
                   doc: "The element type of a set-valued column, which is the type each element refers to."
                 ]
               )

  @grant_schema NimbleOptions.new!(
                  subject: [type: :atom, required: true],
                  resource: [type: :atom, required: true],
                  attributes: [type: {:list, :atom}, default: []]
                )

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Mediate.Schema, only: [resource_type: 1, covers: 1, identity: 1, fact: 2, grant: 1]

      Module.register_attribute(__MODULE__, :mediate_facts, accumulate: true)
      Module.put_attribute(__MODULE__, :mediate_resource_type, nil)
      Module.put_attribute(__MODULE__, :mediate_covers, [])
      Module.put_attribute(__MODULE__, :mediate_identity, nil)
      Module.put_attribute(__MODULE__, :mediate_grant, nil)
      @before_compile Mediate.Schema
    end
  end

  @doc "Declare the resource type this schema's rows are, so a query over it needs a decision."
  defmacro resource_type(type) do
    quote bind_quoted: [type: type] do
      Mediate.Schema.__declare_resource_type__(__MODULE__, type)
    end
  end

  @doc "Declare the associations the parent's decision covers."
  defmacro covers(associations) do
    quote bind_quoted: [associations: associations] do
      Mediate.Schema.__declare_covers__(__MODULE__, associations)
    end
  end

  @doc "Declare that a row of this schema is an identity, and of which kind. That is what makes the mediated repo publish its writes. An identity schema need not declare a resource type, and then the repo records its writes and passes them without a decision."
  defmacro identity(kind) do
    quote bind_quoted: [kind: kind] do
      Mediate.Schema.__declare_identity__(__MODULE__, kind)
    end
  end

  @doc "Declare one fact column and whose fact it is."
  defmacro fact(column, options) do
    quote bind_quoted: [column: column, options: options] do
      Mediate.Schema.__declare_fact__(__MODULE__, column, options)
    end
  end

  @doc "Declare that a row of this schema is a grant."
  defmacro grant(options) do
    quote bind_quoted: [options: options] do
      Mediate.Schema.__declare_grant__(__MODULE__, options)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    facts = Enum.reverse(Module.get_attribute(env.module, :mediate_facts))

    quote do
      @doc false
      @spec __mediate__(:resource_type | :covers | :identity | :facts | :grant) :: term()
      def __mediate__(:resource_type), do: @mediate_resource_type
      def __mediate__(:covers), do: @mediate_covers
      def __mediate__(:identity), do: @mediate_identity
      def __mediate__(:facts), do: unquote(Macro.escape(facts))
      def __mediate__(:grant), do: @mediate_grant
    end
  end

  @doc "The resource type a module declares, or `nil` for a module that declares none or is not a schema."
  @spec resource_type_of(term()) :: atom() | nil
  def resource_type_of(module) do
    if declares?(module), do: module.__mediate__(:resource_type)
  end

  @doc "The associations a module's decision covers, or `[]` where it declares none."
  @spec covers_of(term()) :: [atom()]
  def covers_of(module) do
    if declares?(module), do: module.__mediate__(:covers), else: []
  end

  @doc "The identity kind a module declares, or `nil` for a module that declares none."
  @spec identity_of(term()) :: atom() | nil
  def identity_of(module) do
    if declares?(module), do: module.__mediate__(:identity)
  end

  @doc "A row's primary key: the value of its one key column, or a map of the columns where it has several."
  @spec id_of(struct()) :: term()
  def id_of(%{__struct__: schema} = row) do
    case schema.__schema__(:primary_key) do
      [key] -> Map.get(row, key)
      keys -> Map.new(keys, &{&1, Map.get(row, &1)})
    end
  end

  @doc "Whether a module's rows are identities, which is whether the mediated repo publishes its writes."
  @spec identity?(term()) :: boolean()
  def identity?(module), do: identity_of(module) != nil

  @doc "The fact columns a module declares, in declaration order, or `[]` where it declares none."
  @spec facts_of(term()) :: [Fact.t()]
  def facts_of(module) do
    if declares?(module), do: module.__mediate__(:facts), else: []
  end

  @doc """
  The columns a module declares as facts: its fact columns and the columns
  of its grant, each once, in declaration order.
  """
  @spec fact_columns(term()) :: [atom()]
  def fact_columns(module) do
    columns = Enum.map(facts_of(module), & &1.column) ++ grant_columns(grant_of(module))

    Enum.uniq(columns)
  end

  @doc "The grant a module's rows are, or `nil`."
  @spec grant_of(term()) :: Grant.t() | nil
  def grant_of(module) do
    if declares?(module), do: module.__mediate__(:grant)
  end

  @doc "Whether a module carries fact declarations: a fact column or a grant."
  @spec fact_schema?(term()) :: boolean()
  def fact_schema?(module), do: facts_of(module) != [] or grant_of(module) != nil

  @doc "Whether a module used `Mediate.Schema`."
  @spec declares?(term()) :: boolean()
  def declares?(module) when is_atom(module) and not is_nil(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__mediate__, 1)
  end

  def declares?(_other), do: false

  @doc false
  @spec __declare_resource_type__(module(), atom()) :: :ok
  def __declare_resource_type__(module, type) when is_atom(module) and is_atom(type) and not is_nil(type) do
    case Module.get_attribute(module, :mediate_resource_type) do
      nil -> Module.put_attribute(module, :mediate_resource_type, type)
      other -> raise ArgumentError, "#{inspect(module)} already declares resource_type #{inspect(other)}"
    end
  end

  @doc false
  @spec __declare_covers__(module(), [atom()]) :: :ok
  def __declare_covers__(module, associations) when is_atom(module) and is_list(associations) do
    if !Enum.all?(associations, &is_atom/1) do
      raise ArgumentError, "covers expects a list of association names, got: #{inspect(associations)}"
    end

    declared = Module.get_attribute(module, :mediate_covers)

    case Enum.filter(associations, &(&1 in declared)) do
      [] -> Module.put_attribute(module, :mediate_covers, declared ++ associations)
      repeated -> raise ArgumentError, "#{inspect(module)} already covers #{inspect(repeated)}"
    end
  end

  @doc false
  @spec __declare_identity__(module(), atom()) :: :ok
  def __declare_identity__(module, kind) when is_atom(module) do
    if kind not in @identities do
      raise ArgumentError, "identity expects one of #{inspect(@identities)}, got: #{inspect(kind)}"
    end

    case Module.get_attribute(module, :mediate_identity) do
      nil -> Module.put_attribute(module, :mediate_identity, kind)
      other -> raise ArgumentError, "#{inspect(module)} already declares identity #{inspect(other)}"
    end
  end

  @doc false
  @spec __declare_fact__(module(), atom(), keyword()) :: :ok
  def __declare_fact__(module, column, options) when is_atom(module) and is_atom(column) and is_list(options) do
    options = NimbleOptions.validate!(options, @fact_schema)

    fact = %Fact{
      column: column,
      about: options[:about],
      subject: options[:subject],
      resource: options[:resource],
      element: options[:element]
    }

    Module.put_attribute(module, :mediate_facts, fact)
  end

  @doc false
  @spec __declare_grant__(module(), keyword()) :: :ok
  def __declare_grant__(module, options) when is_atom(module) and is_list(options) do
    options = NimbleOptions.validate!(options, @grant_schema)

    case Module.get_attribute(module, :mediate_grant) do
      nil ->
        grant = %Grant{subject: options[:subject], resource: options[:resource], attributes: options[:attributes]}
        Module.put_attribute(module, :mediate_grant, grant)

      %Grant{} ->
        raise ArgumentError, "#{inspect(module)} already declares a grant"
    end
  end

  defp grant_columns(nil), do: []

  defp grant_columns(%Grant{subject: subject, resource: resource, attributes: attributes}),
    do: [subject, resource | attributes]
end
