defmodule MicroTimerNative.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :micro_timer_native,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler_precompiled, "~> 0.5.4"},
      {:rustler, ">= 0.0.0", optional: true},
      {:ex_doc, "~> 0.29.1", only: :dev, runtime: false}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "MicroTimer",
      canonical: "http://hexdocs.pm/micro_timer_nif",
      source_url: "https://github.com/wstucco/micro_timer_nif",
      extras: [
        "README.md"
      ]
    ]
  end

  defp aliases do
    [
      fmt: [
        "format",
        "cmd cargo fmt --manifest-path native/timer/Cargo.toml"
      ]
    ]
  end
end
