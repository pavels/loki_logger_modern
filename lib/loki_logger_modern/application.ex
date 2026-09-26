defmodule LokiLoggerModern.Application do
  @moduledoc false
  use Application

  @handler_id :loki_logger_modern
  @connect_timeout 10_000

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:loki_logger_modern)

    if Keyword.get(config, :enabled, true) do
      start_enabled(config)
    else
      Supervisor.start_link([], strategy: :one_for_one, name: LokiLoggerModern.Supervisor)
    end
  end

  defp start_enabled(config) do
    level = Keyword.get(config, :level, :info)
    format = Keyword.get(config, :format, "$time $metadata[$level] $message\n")
    metadata = Keyword.get(config, :metadata, :all)

    loki_url =
      Keyword.get(config, :loki_host, "http://localhost:3100") <>
        Keyword.get(config, :loki_path, "/loki/api/v1/push")

    shutdown_timeout = Keyword.get(config, :shutdown_timeout, 5_000)

    # Started in this order and stopped in reverse, so the Finch pool is still up while the
    # Buffer and Exporter deliver pending logs on shutdown.
    children = [
      finch_child_spec(loki_url, config),
      {Task.Supervisor, name: LokiLoggerModern.TaskSupervisor},
      # On shutdown the Buffer (stopped first) hands its entries to the Exporter, which then
      # has up to `shutdown_timeout` to deliver them; the supervisor kills it after that.
      Supervisor.child_spec(
        {LokiLoggerModern.Exporter,
         retry_count: Keyword.get(config, :retry_count, 0),
         retry_delay: Keyword.get(config, :retry_delay, 5_000),
         shutdown_timeout: shutdown_timeout,
         loki_labels: Keyword.get(config, :loki_labels, %{application: "loki_logger_modern"}),
         loki_url: loki_url,
         http_headers: http_headers(config)},
        shutdown: shutdown_timeout + 1_000
      ),
      {LokiLoggerModern.Buffer,
       max_buffer: Keyword.get(config, :max_buffer, 32),
       flush_interval: Keyword.get(config, :flush_interval, 5_000)}
    ]

    with {:ok, pid} <-
           Supervisor.start_link(children,
             strategy: :one_for_one,
             name: LokiLoggerModern.Supervisor
           ) do
      :ok = add_handler(level, format, metadata)
      {:ok, pid}
    end
  end

  @impl true
  def prep_stop(state) do
    # Detach before the supervision tree (Buffer/Exporter) goes down,
    # so no log event can reach a handler whose backing processes are gone.
    :logger.remove_handler(@handler_id)
    state
  end

  @impl true
  def stop(_state) do
    :ok
  end

  # Connections to Loki are pooled and kept alive by Finch. TLS is left to Mint's defaults
  # (certificate and hostname verification against the OS CA store, or CAStore when
  # installed), which `ssl_options` only add to or override.
  defp finch_child_spec(loki_url, config) do
    ssl_options =
      case URI.parse(loki_url).scheme do
        "https" ->
          Keyword.get(config, :ssl_options, [])

        "http" ->
          []

        _ ->
          raise ArgumentError, "loki_host must start with http:// or https://, got: #{loki_url}"
      end

    transport_opts = [timeout: @connect_timeout] ++ ssl_options

    {Finch,
     name: LokiLoggerModern.Finch,
     pools: %{default: [conn_opts: [transport_opts: transport_opts]]}}
  end

  defp http_headers(config) do
    headers = [
      {"content-type", "application/x-protobuf"},
      {"x-scope-orgid", Keyword.get(config, :loki_scope_org_id, "fake")}
    ]

    case {config[:basic_auth_user], config[:basic_auth_password]} do
      {user, password} when is_binary(user) and is_binary(password) ->
        [{"authorization", "Basic " <> Base.encode64(user <> ":" <> password)} | headers]

      _ ->
        headers
    end
  end

  defp add_handler(level, format, metadata) do
    handler_config = %{
      config: %{format: format, metadata: metadata},
      level: level
    }

    case :logger.add_handler(@handler_id, LokiLoggerModern, handler_config) do
      :ok ->
        :ok

      {:error, {:already_exist, _}} ->
        :ok

      {:error, reason} ->
        raise "failed to attach LokiLoggerModern :logger handler: #{inspect(reason)}"
    end
  end
end
