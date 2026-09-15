defmodule Mediate.Cerbos.Propagation do
  @moduledoc """
  How long a rule change takes to reach the sidecar, measured and not
  declared.

  The sidecar reads its policies from a directory and reloads them when the
  directory changes. Nothing tells it to reload, and nothing answers
  whether it has. A caller learns that a change is in force when a question
  answers the new way. That interval is this adapter's `policy_propagation`
  component of revocation latency. A measurement of it is a publish, then a
  poll until the answer changes, then the clock.

  Two moves, so a caller can do both. `swap!/2` and `restore!/2` write
  policy text into the directory and put back what was there, a file
  operation and nothing more. `measure/3` takes the publish as a function,
  runs it, and asks the caller's question until it answers the new way.
  The interval between asks is the floor of any number this produces. The
  deadline is generous, because a directory watch is not instant.

  Nothing here asserts a number. The measurement comes back as a struct of
  milliseconds, for the caller to record. `docs/conformance.md` §2 says how
  the laws print it.
  """

  @interval 10

  @schema NimbleOptions.new!(
            timeout: [
              type: :pos_integer,
              default: 30_000,
              doc: "How long to poll for the change to be in force, in milliseconds."
            ]
          )

  @enforce_keys [:total, :publish, :poll, :floor]
  defstruct [:total, :publish, :poll, :floor]

  @typedoc "Milliseconds: the whole measurement, the publish, the poll, and the interval between asks under it."
  @type t :: %__MODULE__{
          total: non_neg_integer(),
          publish: non_neg_integer(),
          poll: non_neg_integer(),
          floor: pos_integer()
        }

  @doc "The schema of the options a measurement takes: #{NimbleOptions.docs(@schema)}"
  @spec options_schema() :: NimbleOptions.t()
  def options_schema, do: @schema

  @doc """
  Runs `publish`, then polls `until` for the change to be in force. Answers
  what the publish returned and how long each part took. The deadline ends
  a measurement whose change never arrives, with a raise.
  """
  @spec measure((-> result), (-> term()), keyword()) :: {result, t()} when result: term()
  def measure(publish, until, options \\ []) when is_function(publish, 0) and is_function(until, 0) do
    validated = NimbleOptions.validate!(options, @schema)
    started = System.monotonic_time(:millisecond)
    published = publish.()
    at_publish = System.monotonic_time(:millisecond)
    _in_force = until(until, validated[:timeout])
    finished = System.monotonic_time(:millisecond)

    {published,
     %__MODULE__{
       total: finished - started,
       publish: at_publish - started,
       poll: finished - at_publish,
       floor: @interval
     }}
  end

  @doc "The milliseconds between asks, the floor of any measurement `until/2` takes."
  @spec interval() :: pos_integer()
  def interval, do: @interval

  @doc """
  Asks `fun` until it answers something other than `nil` or `false`, or
  until `timeout` milliseconds pass. Answers that value, or raises with the
  last one. The clock is monotonic, so an adjustment of the system clock
  between two asks cannot move the deadline. The interval between asks is
  the floor of any measurement taken this way. A change in force halfway
  through an interval shows at the end of the interval, and the measurement
  says so.
  """
  @spec until((-> term()), pos_integer()) :: term()
  def until(fun, timeout) when is_function(fun, 0) and is_integer(timeout) and timeout > 0 do
    asked(fun, timeout, System.monotonic_time(:millisecond) + timeout, nil)
  end

  @doc "The measurement as the parts a report names, in milliseconds."
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = measurement) do
    [total: measurement.total, publish: measurement.publish, poll: measurement.poll, floor: measurement.floor]
  end

  @doc """
  Writes each `{path, text}` pair under the directory, with the path
  relative to it. Answers what those paths held before, `nil` for a path
  that held nothing.
  """
  @spec swap!(Path.t(), [{Path.t(), String.t()}]) :: [{Path.t(), String.t() | nil}]
  def swap!(directory, files) when is_binary(directory) and is_list(files) do
    Enum.map(files, fn {path, text} -> {path, written!(Path.join(directory, path), text)} end)
  end

  @doc "Puts back what `swap!/2` came back with: the text where there was text, no file where there was none."
  @spec restore!(Path.t(), [{Path.t(), String.t() | nil}]) :: :ok
  def restore!(directory, previous) when is_binary(directory) and is_list(previous) do
    Enum.each(previous, fn {path, text} -> put_back!(Path.join(directory, path), text) end)
  end

  defp asked(fun, timeout, deadline, last) do
    case fun.() do
      unarrived when unarrived in [nil, false] ->
        if System.monotonic_time(:millisecond) >= deadline do
          raise "the change was not in force within #{timeout} ms; the last answer was #{inspect(last)}"
        else
          Process.sleep(@interval)
          asked(fun, timeout, deadline, unarrived)
        end

      arrived ->
        arrived
    end
  end

  defp written!(full, text) do
    previous = read(full)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, text)
    previous
  end

  defp put_back!(full, nil) do
    _removed = File.rm_rf!(full)
    :ok
  end

  defp put_back!(full, text), do: File.write!(full, text)

  defp read(full) do
    case File.read(full) do
      {:ok, text} -> text
      {:error, _absent} -> nil
    end
  end
end
