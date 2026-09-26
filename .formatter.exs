# Used by "mix format"
[
  import_deps: [:protobuf],
  # lib/logproto contains generated protobuf code and is intentionally not formatted
  inputs: [
    "{mix,.formatter}.exs",
    "config/**/*.exs",
    "lib/loki_logger_modern.ex",
    "lib/loki_logger_modern/**/*.ex",
    "test/**/*.{ex,exs}"
  ]
]
