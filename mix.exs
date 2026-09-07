defmodule Libremarket.MixProject do
  use Mix.Project

  def project do
    [
      app: :libremarket,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Libremarket, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:kino, "~> 0.12.3"},
      {:vega_lite, "~> 0.1.11"},
      {:kino_vega_lite, "~> 0.1.10"}
    ]
  end
end
