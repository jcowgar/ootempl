defmodule Ootempl.MixProject do
  use Mix.Project

  def project do
    [
      app: :ootempl,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Office Open XML document templating library for Elixir",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :xmerl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:styler, "~> 1.9", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["LGPL-3.0-only"],
      links: %{
        "GitHub" => "https://github.com/jcowgar/ootempl",
        "Changelog" => "https://github.com/jcowgar/ootempl/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "Ootempl",
      extras: ["README.md"]
    ]
  end
end
