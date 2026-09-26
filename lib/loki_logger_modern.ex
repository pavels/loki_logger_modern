defmodule LokiLoggerModern do
  @moduledoc false
  # Implements the :logger handler callbacks. `@behaviour :logger_handler` is not declared
  # because that behaviour module only exists on OTP 27+.

  @internal_metadata_keys [:pid, :gl, :domain, :crash_reason, :ancestors, :callers]

  def adding_handler(handler_config) do
    {:ok, put_formatter(handler_config)}
  end

  def removing_handler(_handler_config) do
    :ok
  end

  # :logger replaces the whole `config` map on update, so merge it with the previous one
  # to keep options (e.g. `format`) that weren't part of the update.
  def changing_config(:update, %{config: old_config}, %{config: new_config} = new_handler_config) do
    config = old_config |> Map.delete(:formatter) |> Map.merge(new_config)
    {:ok, put_formatter(%{new_handler_config | config: config})}
  end

  def changing_config(:set, _old_handler_config, new_handler_config) do
    {:ok, put_formatter(new_handler_config)}
  end

  # Skip the library's own diagnostics (see LokiLoggerModern.Exporter) to avoid a feedback
  # loop, e.g. push failures being queued for another push while Loki is unreachable.
  # Elixir's Logger prefixes the domain with :elixir.
  def log(%{meta: %{domain: [:elixir, :loki_logger_modern | _]}}, _handler_config) do
    :ok
  end

  def log(%{meta: meta} = log_event, %{config: %{formatter: formatter}}) do
    log_event =
      case formatter.metadata do
        :all -> %{log_event | meta: Map.drop(meta, @internal_metadata_keys)}
        _keys -> log_event
      end

    line = log_event |> Logger.Formatter.format(formatter) |> IO.iodata_to_binary()
    ts_nanos = meta.time * 1_000

    LokiLoggerModern.Buffer.add({ts_nanos, line})
  end

  defp build_formatter(format, metadata) do
    # Colors default to IO.ANSI.enabled?(), which is true when running in a terminal;
    # escape codes don't belong in lines stored in Loki.
    {Logger.Formatter, formatter_config} =
      Logger.Formatter.new(format: format, metadata: metadata, colors: [enabled: false])

    formatter_config
  end

  defp put_formatter(%{config: config} = handler_config) do
    format = Map.get(config, :format, "$time $metadata[$level] $message\n")
    metadata = Map.get(config, :metadata, :all)

    %{handler_config | config: Map.put(config, :formatter, build_formatter(format, metadata))}
  end
end
