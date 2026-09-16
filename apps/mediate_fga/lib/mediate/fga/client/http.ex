defmodule Mediate.Fga.Client.Http do
  @moduledoc """
  The server over HTTP and JSON: one function per call the behaviour names,
  and one telemetry event per call. The event is how a shape test counts
  the engine's own calls.

  The transport is `httpc`, which OTP ships, and the encoder is Elixir's
  `JSON`. So the server adds no dependency to an application that takes
  this adapter. Every call is a `POST` to the address the endpoint names,
  with a deadline. A server that does not answer within it is a failure
  the caller turns into a denial and not a wait.

  This module answers one shape of the pinned server (1.19.0) so that no
  caller has to. The server refuses a read whose tuple key names an object
  type and no object id. So a read for a whole type asks for pages of the
  store and keeps the tuples of that type. That is what makes reconcile's
  pages by type work against a real server. How a tuple itself crosses, on
  a delete, on a write, and on the way back, is the codec's, in
  `infrastructure/`.

  Nothing here knows what a model says. A call either answers the value the
  behaviour names, or fails with an engine error. The error's detail is a
  sentence about what went wrong, which becomes the message of the denial's
  reason.
  """

  @behaviour Mediate.Fga.Client

  alias Mediate.Fga.Client
  alias Mediate.Fga.Client.Check
  alias Mediate.Fga.Client.ListObjects
  alias Mediate.Fga.Client.Page
  alias Mediate.Fga.Client.Read
  alias Mediate.Fga.Client.Write
  alias Mediate.Fga.Infrastructure.Codec

  @connect_timeout 1_000
  @timeout 5_000
  @telemetry [:mediate, :fga, :request]

  @doc "The telemetry event every call emits, once per call, whether it answered or failed."
  @spec telemetry_event() :: [atom()]
  def telemetry_event, do: @telemetry

  @impl Client
  def create_store(endpoint, name) when is_binary(name) do
    with {:ok, answered} <- post(endpoint, "/stores", %{"name" => name}, :create_store) do
      fetched(answered, "id", :create_store)
    end
  end

  @impl Client
  def write_model(endpoint, store, model) when is_binary(store) and is_map(model) do
    with {:ok, answered} <- post(endpoint, "/stores/#{store}/authorization-models", model, :write_model) do
      fetched(answered, "authorization_model_id", :write_model)
    end
  end

  @impl Client
  def check(endpoint, store, %Check{} = request) do
    body = asked(%{"tuple_key" => Codec.key(request.tuple_key)}, request.model, request.consistency, request.context)

    with {:ok, answered} <- post(endpoint, path(store, "check"), body, :check) do
      {:ok, answered["allowed"] == true}
    end
  end

  @impl Client
  def list_objects(endpoint, store, %ListObjects{} = request) do
    asking = %{"type" => request.type, "relation" => request.relation, "user" => request.user}
    body = asked(asking, request.model, request.consistency, request.context)

    with {:ok, answered} <- post(endpoint, path(store, "list-objects"), body, :list_objects) do
      {:ok, Map.get(answered, "objects", [])}
    end
  end

  @impl Client
  def read(endpoint, store, %Read{} = request) do
    with {:ok, answered} <- post(endpoint, path(store, "read"), reading(request), :read) do
      {:ok, page(answered, request)}
    end
  end

  @impl Client
  def write(endpoint, store, %Write{} = request) do
    with {:ok, _answered} <- post(endpoint, path(store, "write"), changes(request), :write) do
      {:ok, length(request.deletes) + length(request.writes)}
    end
  end

  defp path(store, call), do: "/stores/#{store}/#{call}"

  defp asked(body, model, consistency, context) do
    body
    |> put("authorization_model_id", model)
    |> put_consistency(consistency)
    |> put_context(context)
  end

  defp put(body, _field, nil), do: body
  defp put(body, field, value), do: Map.put(body, field, value)

  defp put_consistency(body, :unspecified), do: body
  defp put_consistency(body, :minimize_latency), do: Map.put(body, "consistency", "MINIMIZE_LATENCY")
  defp put_consistency(body, :higher_consistency), do: Map.put(body, "consistency", "HIGHER_CONSISTENCY")

  defp put_context(body, context) when context == %{}, do: body
  defp put_context(body, context), do: Map.put(body, "context", context)

  # The call omits a side with nothing on it. The server refuses a list of
  # no tuple keys, and a call that carries one side alone is the usual one.
  defp changes(%Write{} = request) do
    sides = [{"deletes", keys(request.deletes, &Codec.key/1)}, {"writes", keys(request.writes, &Codec.written/1)}]

    for {field, value} <- sides, value != nil, into: %{}, do: {field, value}
  end

  defp keys([], _shape), do: nil
  defp keys(tuples, shape), do: %{"tuple_keys" => Enum.map(tuples, shape)}

  # A read of a whole object type names no tuple key, because the server
  # refuses one with a type and no id. `keep?/2` keeps the type from the
  # pages instead.
  defp reading(%Read{object_id: nil} = request) do
    put(%{"page_size" => request.limit}, "continuation_token", request.continuation)
  end

  defp reading(%Read{} = request) do
    asking = %{"page_size" => request.limit, "tuple_key" => narrowed(request)}

    put(asking, "continuation_token", request.continuation)
  end

  defp narrowed(%Read{} = request) do
    named = %{"object" => "#{request.object_type}:#{request.object_id}"}

    named
    |> put("relation", request.relation)
    |> put("user", request.user)
  end

  defp page(answered, %Read{} = request) do
    tuples = for tuple <- Map.get(answered, "tuples", []), keep?(tuple, request), do: Codec.stored(tuple)

    %Page{tuples: tuples, continuation: token(Map.get(answered, "continuation_token"))}
  end

  # An empty token is the last page. That is how the server says there is
  # no page after this one.
  defp token(nil), do: nil
  defp token(""), do: nil
  defp token(token), do: token

  defp keep?(%{"key" => key}, %Read{} = request) do
    [type | _id] = String.split(Map.get(key, "object", ""), ":", parts: 2)

    type == request.object_type and named?(key, request)
  end

  defp keep?(_tuple, _request), do: false

  defp named?(key, %Read{} = request) do
    same?(key["relation"], request.relation) and same?(key["user"], request.user) and
      same?(key["object"], object(request))
  end

  defp object(%Read{object_id: nil}), do: nil
  defp object(%Read{} = request), do: "#{request.object_type}:#{request.object_id}"

  defp same?(_value, nil), do: true
  defp same?(value, value), do: true
  defp same?(_value, _asked), do: false

  defp fetched(answered, field, operation) do
    case Map.fetch(answered, field) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _absent -> {:error, Client.error(operation, "the server answered no #{field}")}
    end
  end

  defp post(endpoint, path, body, operation) when is_binary(endpoint) do
    request = {url(endpoint, path), [], ~c"application/json", JSON.encode_to_iodata!(body)}

    measured(path, operation, fn -> :httpc.request(:post, request, http_options(), options()) end)
  end

  defp post(endpoint, _path, _body, operation) do
    {:error, Client.error(operation, "#{inspect(endpoint)} is no address this client reaches")}
  end

  # One event per call, with the duration and the outcome. So a test counts
  # the calls a port operation made, and runs no database query to count.
  defp measured(path, operation, fun) do
    started = System.monotonic_time()
    result = answer(fun.(), operation)
    duration = System.monotonic_time() - started
    :telemetry.execute(@telemetry, %{duration: duration}, %{path: path, outcome: elem(result, 0)})
    result
  end

  defp answer({:ok, {{_version, status, _phrase}, _headers, body}}, operation) when status in 200..299 do
    decoded(body, operation)
  end

  defp answer({:ok, {{_version, status, _phrase}, _headers, body}}, operation) do
    {:error, Client.error(operation, "the server answered #{status}: #{String.slice(to_string(body), 0, 200)}")}
  end

  defp answer({:error, reason}, operation) do
    {:error, Client.error(operation, "the server could not be reached: #{inspect(reason)}")}
  end

  defp decoded(body, operation) do
    case JSON.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, other} -> {:error, Client.error(operation, "the server answered no object: #{inspect(other)}")}
      {:error, reason} -> {:error, Client.error(operation, "the server answered no JSON: #{inspect(reason)}")}
    end
  end

  defp url(endpoint, path), do: String.to_charlist("http://" <> endpoint <> path)

  defp http_options, do: [timeout: @timeout, connect_timeout: @connect_timeout]

  defp options, do: [body_format: :binary]
end
