defmodule LokiLoggerModernTest do
  # The handler, buffer and exporter are global (one per node), so tests can't run concurrently.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  require Logger

  alias LokiLoggerModern.FakeLoki

  @app :loki_logger_modern

  setup do
    server = start_supervised!({FakeLoki, owner: self()})
    on_exit(fn -> Application.stop(@app) end)

    %{port: FakeLoki.port(server)}
  end

  # Restarts the application with exactly the given configuration.
  defp start_loki_logger(port, opts) do
    Application.stop(@app)

    for {key, _} <- Application.get_all_env(@app), do: Application.delete_env(@app, key)

    [loki_host: "http://127.0.0.1:#{port}", format: "[$level] $message", metadata: []]
    |> Keyword.merge(opts)
    |> Enum.each(fn {key, value} -> Application.put_env(@app, key, value) end)

    {:ok, _} = Application.ensure_all_started(@app)
  end

  defp lines(%{streams: [%{entries: entries}]}) do
    Enum.map(entries, & &1.line)
  end

  # Label order within the `{...}` selector isn't significant.
  defp labels(%{labels: "{" <> labels}) do
    labels |> String.trim_trailing("}") |> String.split(",") |> Enum.sort()
  end

  test "pushes formatted log lines with the configured labels", %{port: port} do
    start_loki_logger(port, max_buffer: 1, loki_labels: %{application: "my_app", env: "test"})

    before = System.os_time(:second)
    Logger.info("hello loki")

    assert_receive {:loki_push, _headers, %{streams: [stream]}}
    assert labels(stream) == [~s(application="my_app"), ~s(env="test")]
    assert [%{line: "[info] hello loki", timestamp: timestamp}] = stream.entries
    assert timestamp.seconds in before..(before + 5)
  end

  test "buffers entries until max_buffer is reached", %{port: port} do
    start_loki_logger(port, max_buffer: 3)

    Logger.info("one")
    Logger.info("two")
    refute_receive {:loki_push, _, _}, 200

    Logger.info("three")
    assert_receive {:loki_push, _, request}
    assert lines(request) == ["[info] one", "[info] two", "[info] three"]
  end

  test "flushes the buffer periodically when flush_interval is set", %{port: port} do
    start_loki_logger(port, max_buffer: 100, flush_interval: 50)

    Logger.info("flushed by timer")

    assert_receive {:loki_push, _, request}
    assert lines(request) == ["[info] flushed by timer"]
  end

  test "drops messages below the configured level", %{port: port} do
    start_loki_logger(port, level: :warning, max_buffer: 2)

    Logger.debug("debug")
    Logger.info("info")
    Logger.warning("warning")
    Logger.error("error")

    assert_receive {:loki_push, _, request}
    assert lines(request) == ["[warning] warning", "[error] error"]
  end

  test "never adds ANSI colors, even when the terminal supports them", %{port: port} do
    ansi_enabled = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, true)

    on_exit(fn ->
      if is_nil(ansi_enabled),
        do: Application.delete_env(:elixir, :ansi_enabled),
        else: Application.put_env(:elixir, :ansi_enabled, ansi_enabled)
    end)

    start_loki_logger(port, max_buffer: 2)

    Logger.info("info")
    Logger.error("error")

    assert_receive {:loki_push, _, request}
    assert lines(request) == ["[info] info", "[error] error"]
  end

  test "includes only the configured metadata", %{port: port} do
    start_loki_logger(port, max_buffer: 1, format: "$metadata$message", metadata: [:request_id])

    Logger.info("with metadata", request_id: "abc123", user_id: 42)

    assert_receive {:loki_push, _, request}
    assert lines(request) == ["request_id=abc123 with metadata"]
  end

  test "metadata: :all omits process-internal metadata", %{port: port} do
    start_loki_logger(port, max_buffer: 1, format: "$metadata$message", metadata: :all)

    Logger.info("all metadata", request_id: "abc123")

    assert_receive {:loki_push, _, request}
    assert [line] = lines(request)
    assert line =~ "request_id=abc123"
    refute line =~ "pid="
    refute line =~ "gl="
  end

  test "sends protobuf content type, tenant and basic auth headers", %{port: port} do
    start_loki_logger(port,
      max_buffer: 1,
      loki_scope_org_id: "tenant-1",
      basic_auth_user: "user",
      basic_auth_password: "secret"
    )

    Logger.info("authenticated")

    assert_receive {:loki_push, headers, _request}
    headers = Map.new(headers)
    assert headers["content-type"] == "application/x-protobuf"
    assert headers["x-scope-orgid"] == "tenant-1"
    assert headers["authorization"] == "Basic " <> Base.encode64("user:secret")
  end

  test "format and metadata can be updated at runtime", %{port: port} do
    start_loki_logger(port, max_buffer: 1)

    :ok = :logger.update_handler_config(@app, :config, %{format: "changed: $message"})
    Logger.info("new format")
    assert_receive {:loki_push, _, request}
    assert lines(request) == ["changed: new format"]

    # Updating only :metadata keeps the previously configured format.
    :ok = :logger.update_handler_config(@app, :config, %{metadata: [:request_id]})
    Logger.info("new metadata", request_id: "r1")
    assert_receive {:loki_push, _, request}
    assert lines(request) == ["changed: new metadata"]
  end

  test "keeps pushing after Loki rejects a request" do
    stop_supervised!(FakeLoki)
    port = FakeLoki.port(start_supervised!({FakeLoki, owner: self(), status: 500}))

    output =
      capture_log(fn ->
        start_loki_logger(port, max_buffer: 1)

        Logger.info("first")
        assert_receive {:loki_push, _, request}
        assert lines(request) == ["[info] first"]

        Logger.info("second")
        assert_receive {:loki_push, _, request}
        assert lines(request) == ["[info] second"]

        # The error diagnostics must not be pushed to Loki themselves.
        refute_receive {:loki_push, _, _}, 200
      end)

    assert output =~ "Unexpected status code from Loki: 500"
  end

  test "retries failed pushes until Loki becomes reachable" do
    stop_supervised!(FakeLoki)

    # Reserve a free port, then leave it closed so the first pushes fail.
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)

    output =
      capture_log(fn ->
        start_loki_logger(port, max_buffer: 1, retry_count: 20, retry_delay: 50)

        Logger.info("delivered eventually")
        Process.sleep(200)
        refute_received {:loki_push, _, _}

        start_supervised!({FakeLoki, owner: self(), port: port})
        assert_receive {:loki_push, _, request}, 2_000
        assert lines(request) == ["[info] delivered eventually"]
        refute_receive {:loki_push, _, _}, 200
      end)

    assert output =~ "retrying in 50ms"
  end

  test "escapes quotes, backslashes and newlines in label values", %{port: port} do
    start_loki_logger(port, max_buffer: 1, loki_labels: %{app: ~s(say "hi" \\ bye\n)})

    Logger.info("escaped")

    assert_receive {:loki_push, _, %{streams: [stream]}}
    assert stream.labels == ~S({app="say \"hi\" \\ bye\n"})
  end

  test "flushes every 5 seconds by default", %{port: port} do
    start_loki_logger(port, [])

    assert %{flush_interval: 5_000} = :sys.get_state(LokiLoggerModern.Buffer)
  end

  test "flushes buffered entries when the application stops", %{port: port} do
    start_loki_logger(port, max_buffer: 100, flush_interval: 0)

    Logger.info("buffered")
    refute_receive {:loki_push, _, _}, 100

    :ok = Application.stop(@app)
    assert_received {:loki_push, _, request}
    assert lines(request) == ["[info] buffered"]
  end

  test "delivers in-flight and queued batches when the application stops" do
    stop_supervised!(FakeLoki)
    port = FakeLoki.port(start_supervised!({FakeLoki, owner: self(), delay: 200}))
    start_loki_logger(port, max_buffer: 1, flush_interval: 0)

    # The first push is held in flight by the slow server, the others queue up behind it.
    Logger.info("one")
    Logger.info("two")
    Logger.info("three")

    :ok = Application.stop(@app)

    assert_received {:loki_push, _, one}
    assert_received {:loki_push, _, two}
    assert_received {:loki_push, _, three}

    assert Enum.flat_map([one, two, three], &lines/1) == [
             "[info] one",
             "[info] two",
             "[info] three"
           ]
  end

  test "gives up on pending batches after shutdown_timeout" do
    stop_supervised!(FakeLoki)
    port = FakeLoki.port(start_supervised!({FakeLoki, owner: self(), delay: 1_500}))
    start_loki_logger(port, max_buffer: 1, flush_interval: 0, shutdown_timeout: 100)

    Logger.info("one")
    Logger.info("two")

    {micros, :ok} = :timer.tc(fn -> Application.stop(@app) end)
    assert micros < 1_000_000
  end

  test "does nothing when disabled", %{port: port} do
    start_loki_logger(port, enabled: false, max_buffer: 1)

    assert {:error, {:not_found, :loki_logger_modern}} = :logger.get_handler_config(@app)
    refute Process.whereis(LokiLoggerModern.Buffer)

    Logger.info("ignored")
    refute_receive {:loki_push, _, _}, 200
  end
end
