defmodule Distribunator.MixProject do
  use Mix.Project

  def project do
    [
      app: :distribunator,
      version: "0.1.3",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end

  defp package do
    [
      description: "Utilities supporting process distribution across nodes and node connections",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sampscl/distribunator"},
      homepage_url: "https://github.com/sampscl/distribunator",
      source_url:  "https://github.com/sampscl/distribunator/tree/v0.1.3",
    ]
  end
end
