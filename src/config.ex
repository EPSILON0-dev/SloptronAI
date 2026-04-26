defmodule SloptronAI.Config do
  @moduledoc false

  defstruct [
    :openrouter_api_url,
    :openrouter_api_key,
    :main_model,
    :unslopifier_model,
    :quiet,
    :no_unslopifier,
    :slopifier_rounds
  ]

  defmodule NoSuchFileException do
    defexception message: "default message"
  end

  defmodule InvalidConfigException do
    defexception message: "default message"
  end

  defp default_config() do
    %__MODULE__{
      openrouter_api_url: "https://openrouter.ai/api/v1",
      openrouter_api_key: System.get_env("OPENROUTER_API_KEY"),
      main_model: "openai/gpt-4.1-mini",
      unslopifier_model: "qwen/qwen3.5-0.6b",
      quiet: false,
      no_unslopifier: false,
      slopifier_rounds: 3
    }
  end

  defp load_cli_config(config) do
    {opts, args, invalid} =
      OptionParser.parse(System.argv(),
        switches: [
          "--openrouter-api-url": :string,
          "--openrouter-api-key": :string,
          "--main-model": :string,
          "--unslopifier-model": :string,
          "--no-unslopifier": :boolean,
          "--slopifier-rounds": :integer,
          quiet: :boolean
        ]
      )

    if invalid != [] do
      IO.puts(:stderr, "Invalid command-line options: #{inspect(invalid)}")
      System.halt(1)
    end

    query = Enum.join(args, " ")

    config =
      Enum.reduce(opts, config, fn {key, value}, acc ->
        atom_key = key |> to_string() |> String.replace("-", "_") |> String.to_atom()

        if atom_key in Map.keys(%__MODULE__{}) do
          Map.merge(acc, %{atom_key => value})
        else
          raise InvalidConfigException, message: "Invalid config key provided: #{key}"
        end
      end)

    {config, query}
  end

  def load_config_and_query() do
    config = default_config()
    {config, query} = load_cli_config(config)

    if config.openrouter_api_key == nil do
      IO.puts(
        :stderr,
        "OpenRouter API key is required. Set it via config file or OPENROUTER_API_KEY environment variable."
      )

      System.halt(1)
    end

    {config, query}
  end
end
