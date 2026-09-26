# LokiLoggerModern

[![Hex.pm Version](https://img.shields.io/hexpm/v/loki_logger_modern.svg?style=flat)](https://hex.pm/packages/loki_logger_modern)

LokiLoggerModern is an Elixir [`:logger` handler](https://www.erlang.org/doc/apps/kernel/logger_handler.html)
that ships your application logs to [Grafana Loki](https://github.com/grafana/loki).

> **Attribution:** this project is based on [LokiLogger](https://github.com/wardbekker/LokiLogger)
> by Ward Bekker (and includes improvements from the [phanmn/LokiLogger](https://github.com/phanmn/LokiLogger) fork).
> It was reworked to use Elixir's modern `:logger` handler API and is published under
> a new name, `loki_logger_modern`. Many thanks to the original authors and contributors.

## Features

* Implements the Erlang/Elixir `:logger` handler API (Elixir 1.18+), no legacy `:gen_event` backend
* Attaches itself automatically when the application starts
* Elixir `Logger.Formatter` formatting and metadata support
* Snappy-compressed protobuf payload sent to the Loki push API
* Buffered, asynchronous delivery (log calls never block on HTTP)
* Periodic flushing of the buffer (every 5 seconds by default)
* Pending logs are delivered when the application stops
* Optional retry of failed pushes (network errors)
* Pooled keep-alive connections ([Finch](https://hex.pm/packages/finch))
* HTTPS with certificate verification by default; custom CA or mTLS via `ssl_options`
* `X-Scope-OrgID` header for Loki multi-tenancy
* HTTP basic authentication

## Installation

Add `loki_logger_modern` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:loki_logger_modern, "~> 1.0"}
  ]
end
```

Requires Elixir 1.18 or later.

## Configuration

LokiLoggerModern is configured through its application environment, e.g. in `config/config.exs`
or `config/runtime.exs`:

```elixir
import Config

config :loki_logger_modern,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module],
  max_buffer: 300,
  flush_interval: 5_000,
  loki_labels: %{application: "my_app", elixir_node: node()},
  loki_host: "http://localhost:3100"
```

### Options

| Option | Default | Description |
| --- | --- | --- |
| `enabled` | `true` | Set to `false` to not start anything nor attach the handler, e.g. in `config/test.exs`. |
| `loki_host` | `"http://localhost:3100"` | Base URL of the Loki server. |
| `loki_path` | `"/loki/api/v1/push"` | Path of the Loki push API. |
| `loki_labels` | `%{application: "loki_logger_modern"}` | Labels attached to the log stream (used to select it in e.g. Grafana). |
| `loki_scope_org_id` | `"fake"` | Tenant ID sent in the `X-Scope-OrgID` header (Loki multi-tenancy). |
| `basic_auth_user` / `basic_auth_password` | `nil` | Enables HTTP basic authentication when both are set. |
| `ssl_options` | `[]` | Extra [`:ssl` client options](https://www.erlang.org/doc/apps/ssl/ssl.html#t:tls_client_option/0) for `https` hosts, e.g. `[cacertfile: "/path/to/ca.pem"]` for a private CA, or `certfile`/`keyfile` for mTLS. By default the server certificate is verified against the OS CA store (connections are made by [Finch](https://hex.pm/packages/finch)/[Mint](https://hexdocs.pm/mint/Mint.HTTP.html#connect/4-transport-options)); on systems without one, add [`:castore`](https://hex.pm/packages/castore) to your dependencies. |
| `level` | `:info` | Minimum level of messages sent to Loki (`:debug`, `:info`, `:notice`, `:warning`, `:error`, ...). |
| `format` | `"$time $metadata[$level] $message\n"` | [`Logger.Formatter`](https://hexdocs.pm/logger/Logger.Formatter.html) format string. |
| `metadata` | `:all` | Metadata keys included by `$metadata`, or `:all`. |
| `max_buffer` | `32` | Number of log entries buffered before they are pushed to Loki. |
| `flush_interval` | `5_000` | The buffer is also pushed every `flush_interval` milliseconds, so logs aren't held back in quiet periods. `0` disables periodic flushing. |
| `retry_count` | `0` | How many times a failed push is retried. `0` disables retries, a negative value retries forever. |
| `retry_delay` | `5_000` | Delay between retries in milliseconds. |
| `shutdown_timeout` | `5_000` | How long (ms) pending logs may take to be delivered when the application stops. |

> **Note:** pushes are sent one at a time; batches that fill up while a push is in flight
> (or being retried) are queued in memory. With a finite `retry_count` every push eventually
> completes or gives up, so the queue drains, but with `retry_count` < 0 (retry forever)
> **the queue is unbounded**: if Loki stays unreachable, memory usage grows for as long as
> the application keeps logging.

When the application stops, buffered entries are flushed, the in-flight push is given time to
finish and queued batches are sent (without retries), all within `shutdown_timeout`
milliseconds; anything still pending after that is dropped.

### Delivery errors

Failed pushes (Loki unreachable, non-2xx responses, retries) are reported through `Logger`
under the `[:loki_logger_modern]` domain, so they show up in your other handlers (e.g. the
console) but are never sent to Loki themselves. To silence them, add a domain filter to the
handler in question, e.g. for the default console handler:

```elixir
:logger.add_handler_filter(
  :default,
  :no_loki_logger_modern,
  {&:logger_filters.domain/2, {:stop, :sub, [:elixir, :loki_logger_modern]}}
)
```

### Runtime configuration

`level`, `format` and `metadata` can be changed at runtime:

```elixir
:logger.update_handler_config(:loki_logger_modern, :level, :debug)
:logger.update_handler_config(:loki_logger_modern, :config, %{format: "$message\n", metadata: :all})
```

All other options are read once, when the application starts.

## Development

### Tests

```shell
mix test
```

The tests don't need a running Loki: they start a small fake Loki push endpoint
(`test/support/fake_loki.ex`) and assert on the decoded protobuf payloads it receives.

### Protobuf regeneration

Only needed when updating the Loki protobuf definitions. Requires `protoc` and the Elixir
plugin (`mix escript.install hex protobuf`, with `~/.mix/escripts` on your `PATH`). The
plugin writes the file into a directory per package, so generate it elsewhere and move it
into place:

```shell
mkdir -p /tmp/logproto
protoc --proto_path=lib/logproto --elixir_out=/tmp/logproto \
  --elixir_opt=package_prefix=loki_logger_modern lib/logproto/loki.proto
mv /tmp/logproto/loki_logger_modern/logproto/loki.pb.ex lib/logproto/loki.pb.ex
```

### Publishing

Pushing a tag matching `v*.*.*` (e.g. `v1.0.0`) publishes the package to Hex via GitHub Actions.
The `HEX_API_KEY` repository secret must be set.

## License

Copyright (c) 2019 Ward Bekker and contributors (original [LokiLogger](https://github.com/wardbekker/LokiLogger))

Copyright (c) 2024-2026 [Pavel Sorejs](https://github.com/pavels) (LokiLoggerModern)

The source code is released under the Apache v2.0 License.
Check [LICENSE](LICENSE) for more information.
