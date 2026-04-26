defmodule SloptronAI.MixProject do
  use Mix.Project

  def project do
    [
      app: :sloptron_ai,
      version: "1.0.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :dev,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4"}
    ]
  end

  defp aliases do
    [
      run: ["run src/main.ex"]
    ]
  end
end
