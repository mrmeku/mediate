defmodule Mediate.Cerbos.Domain.Plan do
  @moduledoc false
  # A plan turned into a `dynamic` over the rows of the resource type.
  #
  # The server answers a plan request with a filter over the resource
  # attributes it did not resolve. That is what makes a list one query and
  # not a decision per row. Three shapes come back.
  #
  # A plan that admits every row becomes `true`. A plan that admits none is
  # `:denied`. A conditional plan is an expression tree over
  # `request.resource.attr.<name>` and values. This module compiles the
  # tree against the declarations. An attribute from a column becomes a
  # comparison on that column. An attribute from a subquery becomes
  # membership in the ids the subquery selects for the subject at the
  # moment the request carries.
  #
  # An attribute the server did not resolve, compared with nothing, becomes
  # a null test on the column. The policy asks about a row whose column
  # holds nothing. SQL answers nothing, and not true, to `= NULL`, so the
  # comparison is `is_nil`. An order comparison against nothing has no such
  # sense, and the compiler refuses it.
  #
  # An expression this module cannot compile is neither guessed at nor
  # dropped. It is a refused plan, and the library then answers the filter
  # as a denial. The reason: a plan narrowed by half is a query that returns
  # rows a policy denies. A plan dropped whole is a list that returns
  # nothing where the policy allows. The honest answer is that the plan
  # does not carry this rule.
  #
  # The compile runs no query. This module builds the subquery an attribute
  # names, and whoever runs the rule runs it.

  import Ecto.Query, only: [dynamic: 2, from: 2, subquery: 1]

  alias Mediate.Cerbos.Attribute
  alias Mediate.Cerbos.Declarations

  @operators "eq, ne, lt, le, gt, ge, in, has, and, or, not"

  @enforce_keys [:subject, :action, :context, :plan, :declarations, :type, :schema, :key]
  defstruct @enforce_keys

  @typedoc "The whole input of a compile: who asks what of which type, the plan, and the declarations behind it."
  @type t :: %__MODULE__{
          subject: Mediate.subject(),
          action: atom(),
          context: Mediate.context(),
          plan: map(),
          declarations: Declarations.t(),
          type: atom(),
          schema: module(),
          key: atom()
        }

  @doc """
  The rule the plan carries:

  - `{:ok, rule}` for a plan that every row of the type meets or fails
  - `:denied` for a plan that admits no row
  - `{:error, text}` for a plan the compiler refuses, and the text says why
  """
  @spec compile(t()) :: {:ok, Ecto.Query.dynamic_expr()} | :denied | {:error, String.t()}
  def compile(%__MODULE__{plan: plan} = compiling) when is_map(plan), do: filtered(compiling, plan)

  defp filtered(_plan, %{"kind" => "KIND_ALWAYS_DENIED"}), do: :denied
  defp filtered(_plan, %{"kind" => "KIND_ALWAYS_ALLOWED"}), do: {:ok, dynamic([_row], true)}
  defp filtered(plan, %{"kind" => "KIND_CONDITIONAL", "condition" => condition}), do: operand(plan, condition)

  defp filtered(plan, other), do: refused(plan, "carries no filter Mediate.Cerbos compiles: " <> abbreviated(other))

  defp operand(plan, %{"expression" => expression}) when is_map(expression), do: expression(plan, expression)

  defp operand(plan, other), do: refused(plan, "carries an operand that is no expression: " <> abbreviated(other))

  defp expression(plan, %{"operator" => "and", "operands" => operands}) when is_list(operands) do
    combined(plan, operands, :and)
  end

  defp expression(plan, %{"operator" => "or", "operands" => operands}) when is_list(operands) do
    combined(plan, operands, :or)
  end

  defp expression(plan, %{"operator" => "not", "operands" => [operand]}) do
    with {:ok, expression} <- operand(plan, operand), do: {:ok, dynamic([row], not (^expression))}
  end

  defp expression(plan, %{"operator" => operator, "operands" => [left, right]}) when is_binary(operator) do
    binary(plan, operator, left, right)
  end

  defp expression(plan, other),
    do: refused(plan, "uses an expression Mediate.Cerbos does not compile: " <> abbreviated(other))

  defp combined(plan, operands, connective) do
    step = fn operand, {:ok, acc} -> joined(operand(plan, operand), connective, acc) end

    case Enum.reduce_while(operands, {:ok, nil}, step) do
      {:ok, nil} -> refused(plan, "uses #{connective} with no operands")
      answer -> answer
    end
  end

  defp joined({:ok, expression}, _connective, nil), do: {:cont, {:ok, expression}}
  defp joined({:ok, expression}, :and, acc), do: {:cont, {:ok, dynamic([row], ^acc and ^expression)}}
  defp joined({:ok, expression}, :or, acc), do: {:cont, {:ok, dynamic([row], ^acc or ^expression)}}
  defp joined({:error, text}, _connective, _acc), do: {:halt, {:error, text}}

  # One side names an attribute and the other a value. A comparison of two
  # attributes, or of two values, is no rule over the rows.
  defp binary(plan, operator, left, right) do
    case {sided(plan, left), sided(plan, right)} do
      {{:ok, {:source, source}}, {:ok, {:value, value}}} -> applied(plan, operator, source, value)
      {{:ok, {:value, value}}, {:ok, {:source, source}}} -> applied(plan, flipped(operator), source, value)
      {{:error, text}, _right} -> {:error, text}
      {_left, {:error, text}} -> {:error, text}
      {_left, _right} -> refused(plan, "compares #{operator} between two sides Mediate.Cerbos cannot place")
    end
  end

  defp sided(_plan, %{"value" => value}), do: {:ok, {:value, value}}
  defp sided(plan, %{"variable" => name}) when is_binary(name), do: variable(plan, name)
  defp sided(plan, other), do: refused(plan, "compares against " <> abbreviated(other))

  defp variable(plan, name) do
    case String.split(name, ".") do
      ["request", "resource", "attr", attribute] -> declared(plan, attribute)
      ["request", "resource", "id"] -> {:ok, {:source, {:column, plan.key}}}
      _other -> refused(plan, "reads #{name}, which is no resource attribute")
    end
  end

  defp declared(%__MODULE__{declarations: declarations, type: type} = plan, name) do
    attributes = Declarations.attributes_of(declarations, {:resource, type})

    case Enum.find(attributes, &(Atom.to_string(&1.name) == name)) do
      %Attribute{source: source} -> {:ok, {:source, source}}
      nil -> refused(plan, "reads the attribute #{name}, which #{inspect(declarations)} does not name")
    end
  end

  defp applied(%__MODULE__{key: key} = plan, "has", {:subquery, fun}, value) when is_binary(value) do
    ids = from(row in subquery(fun.(plan.subject, plan.context)), where: row.value == ^value, select: row.id)
    {:ok, dynamic([row], field(row, ^key) in subquery(ids))}
  end

  defp applied(_plan, "eq", {:column, column}, nil), do: {:ok, dynamic([row], is_nil(field(row, ^column)))}
  defp applied(_plan, "ne", {:column, column}, nil), do: {:ok, dynamic([row], not is_nil(field(row, ^column)))}

  defp applied(plan, operator, {:column, _column}, nil) do
    refused(plan, "compares #{operator} with nothing, which reads as no rule over the rows")
  end

  defp applied(plan, "in", {:column, column}, values) when is_list(values) do
    with {:ok, cast} <- cast_all(plan, column, values), do: {:ok, dynamic([row], field(row, ^column) in ^cast)}
  end

  defp applied(plan, operator, {:column, column}, value) do
    with {:ok, cast} <- cast(plan, column, value), do: compared(plan, operator, column, cast)
  end

  defp applied(plan, operator, {:subquery, _fun}, value) do
    refused(plan, "uses #{operator} over a subquery attribute and " <> abbreviated(value))
  end

  defp compared(_plan, "eq", column, value), do: {:ok, dynamic([row], field(row, ^column) == ^value)}
  defp compared(_plan, "ne", column, value), do: {:ok, dynamic([row], field(row, ^column) != ^value)}
  defp compared(_plan, "lt", column, value), do: {:ok, dynamic([row], field(row, ^column) < ^value)}
  defp compared(_plan, "le", column, value), do: {:ok, dynamic([row], field(row, ^column) <= ^value)}
  defp compared(_plan, "gt", column, value), do: {:ok, dynamic([row], field(row, ^column) > ^value)}
  defp compared(_plan, "ge", column, value), do: {:ok, dynamic([row], field(row, ^column) >= ^value)}

  defp compared(plan, operator, _column, _value) do
    refused(
      plan,
      "uses the operator #{operator}, which Mediate.Cerbos does not compile; keep the condition to #{@operators}"
    )
  end

  # `in` reads as membership, so the sides swap into `has` on the attribute
  # that holds the value. The orderings swap with them.
  defp flipped("in"), do: "has"
  defp flipped("lt"), do: "gt"
  defp flipped("le"), do: "ge"
  defp flipped("gt"), do: "lt"
  defp flipped("ge"), do: "le"
  defp flipped(operator), do: operator

  defp cast_all(plan, column, values) do
    step = fn value, {:ok, acc} ->
      case cast(plan, column, value) do
        {:ok, cast} -> {:cont, {:ok, [cast | acc]}}
        {:error, text} -> {:halt, {:error, text}}
      end
    end

    with {:ok, cast} <- Enum.reduce_while(values, {:ok, []}, step), do: {:ok, Enum.reverse(cast)}
  end

  defp cast(%__MODULE__{schema: schema} = plan, column, value) do
    case schema.__schema__(:type, column) do
      nil -> refused(plan, "reads #{column}, which #{inspect(schema)} does not hold")
      type -> cast_type(plan, type, column, value)
    end
  end

  defp cast_type(plan, type, column, value) do
    case Ecto.Type.cast(type, value) do
      {:ok, cast} -> {:ok, cast}
      _error -> refused(plan, "compares #{column} with #{abbreviated(value)}, which the column cannot hold")
    end
  end

  defp refused(%__MODULE__{action: action, type: type}, text) do
    {:error, "the plan for #{inspect(action)} on #{inspect(type)} #{text}"}
  end

  defp abbreviated(term), do: String.slice(inspect(term), 0, 200)
end
