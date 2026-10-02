defmodule Mediate.Cerbos.Client do
  @moduledoc """
  The server over HTTP and JSON: one function per endpoint the engine
  asks, and one telemetry event per call.

  The transport is `httpc`, which OTP ships, and the encoder is Elixir's
  `JSON`. So this engine adds no dependency to a deployment that takes it.
  Every call is a `POST` or a `GET` to the address the configuration entry
  names, with a deadline. A server that does not answer within the
  deadline is a failure. The caller turns the failure into a denial and
  never waits.

  Nothing here knows what a policy says. A call answers with the decoded
  body, or fails with a sentence that names the server and what went
  wrong. That sentence becomes the message of the engine error, which the
  denial carries.

  The event is how a budget test counts the engine's own calls.
  """

  @connect_timeout 1_000
  @timeout 5_000
  @event [:mediate, :cerbos, :request]

  @typedoc "The address of a server, a host and a port."
  @type address :: String.t()

  @doc "The telemetry event every call emits, once per call, whether it answered or failed."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "A decision for one principal over resources: `POST /api/check/resources`."
  @spec check_resources(address(), map()) :: {:ok, map()} | {:error, String.t()}
  def check_resources(address, body) when is_binary(address) and is_map(body) do
    post(address, "/api/check/resources", body)
  end

  @doc "A plan for one principal, resource type, and action: `POST /api/plan/resources`."
  @spec plan_resources(address(), map()) :: {:ok, map()} | {:error, String.t()}
  def plan_resources(address, body) when is_binary(address) and is_map(body) do
    post(address, "/api/plan/resources", body)
  end

  @doc "The version and the commit of the server itself: `GET /api/server_info`."
  @spec server_info(address()) :: {:ok, map()} | {:error, String.t()}
  def server_info(address) when is_binary(address), do: get(address, "/api/server_info")

  @doc "Whether the server's health answer is `SERVING`: `GET /_cerbos/health`."
  @spec healthy?(address()) :: boolean()
  def healthy?(address) when is_binary(address) do
    match?({:ok, %{"status" => "SERVING"}}, get(address, "/_cerbos/health"))
  end

  defp post(address, path, body) do
    request = {url(address, path), [], ~c"application/json", JSON.encode_to_iodata!(body)}
    measured(address, path, fn -> :httpc.request(:post, request, http_options(), options()) end)
  end

  defp get(address, path) do
    measured(address, path, fn -> :httpc.request(:get, {url(address, path), []}, http_options(), options()) end)
  end

  defp measured(address, path, fun) do
    started = System.monotonic_time()
    result = answer(address, fun.())
    duration = System.monotonic_time() - started
    :telemetry.execute(@event, %{duration: duration}, %{address: address, path: path, outcome: elem(result, 0)})
    result
  end

  defp answer(address, {:ok, {{_version, 200, _phrase}, _headers, body}}), do: decoded(address, body)

  defp answer(address, {:ok, {{_version, status, _phrase}, _headers, body}}) do
    {:error, "#{server(address)} answered #{status}: #{String.slice(to_string(body), 0, 200)}"}
  end

  defp answer(address, {:error, reason}), do: {:error, "#{server(address)} could not be reached: #{inspect(reason)}"}

  defp decoded(address, body) do
    case JSON.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, other} -> {:error, "#{server(address)} answered a body that is not a JSON object: #{inspect(other)}"}
      {:error, reason} -> {:error, "#{server(address)} answered a body that is not a JSON object: #{inspect(reason)}"}
    end
  end

  defp server(address), do: "the Cerbos server at #{address}"

  defp url(address, path), do: String.to_charlist("http://" <> address <> path)

  defp http_options, do: [timeout: @timeout, connect_timeout: @connect_timeout]

  defp options, do: [body_format: :binary]
end
