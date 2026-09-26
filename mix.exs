defmodule LokiLoggerModern.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/pavels/loki_logger_modern"

  def project do
    [
      app: :loki_logger_modern,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "LokiLoggerModern",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LokiLoggerModern.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:bandit, "~> 1.5", only: :test},
      {:finch, "~> 0.19"},
      {:protobuf, "~> 0.17.0"},
      {:snappyex, "~> 0.1.3"}
    ]
  end

  defp description() do
    "Elixir :logger handler for Grafana Loki"
  end

  defp package() do
    [
      name: "loki_logger_modern",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      maintainers: ["Pavel Sorejs"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
