defmodule GenPool.MixProject do
  use Mix.Project

  @source_url "https://github.com/eliasdarruda/gen_pool"

  def project do
    [
      app: :gen_pool,
      version: "0.1.0",
      description: "Gen Pool",
      elixir: "~> 1.14",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:sbroker, "~> 1.0.0"},
      {:ane, "~> 0.1.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: :dev}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      licenses: ["Apache-2.0"],
      links: %{GitHub: @source_url}
    ]
  end
end
