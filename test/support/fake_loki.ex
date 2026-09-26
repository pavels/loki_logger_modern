defmodule LokiLoggerModern.FakeLoki do
  @moduledoc false
  # Minimal stand-in for the Loki push API. Every push is decoded and forwarded to the
  # `:owner` process as `{:loki_push, req_headers, %PushRequest{}}`. `:status` sets the response
  # status (default 204) and `:delay` (ms) slows down the response, to keep a push in flight.
  @behaviour Plug

  import Plug.Conn

  alias LokiLoggerModern.Logproto.PushRequest

  def child_spec(opts) do
    [
      plug: {__MODULE__, Keyword.take(opts, [:owner, :status, :delay])},
      ip: :loopback,
      port: Keyword.get(opts, :port, 0),
      startup_log: false
    ]
    |> Bandit.child_spec()
    |> Supervisor.child_spec(id: __MODULE__)
  end

  def port(server) do
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    port
  end

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(%{method: "POST", request_path: "/loki/api/v1/push"} = conn, opts) do
    {:ok, body, conn} = read_body(conn)
    payload = SnappyEx.decompress!(body)

    send(
      Keyword.fetch!(opts, :owner),
      {:loki_push, conn.req_headers, PushRequest.decode(payload)}
    )

    Process.sleep(Keyword.get(opts, :delay, 0))
    send_resp(conn, Keyword.get(opts, :status, 204), "")
  end

  def call(conn, _opts) do
    send_resp(conn, 404, "")
  end
end
