defmodule Server.MixProject do
  use Mix.Project

  def project do
    [
      app: :messenger_server,
      version: "0.1.0",
      elixir: ">= 1.15.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Server.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.12.4"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, ">= 0.19.2"},
      {:bcrypt_elixir, ">= 3.2.0"}
    ]
  end
end
