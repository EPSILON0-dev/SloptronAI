Code.require_file(Path.join(__DIR__, "config.ex"))
Code.require_file(Path.join(__DIR__, "openrouter.ex"))
Code.require_file(Path.join(__DIR__, "slopify.ex"))

defmodule SloptronAI.Main do
  {config, query} = SloptronAI.Config.load_config_and_query()

  {text, cost} = SloptronAI.Slopify.run_slopify(config, query)
  cost = cost |> :erlang.float_to_binary(decimals: 7)

  IO.puts(:stderr, "\n\x1b[1mFinal slopified output: \x1b[2m(Estimated cost: $#{cost})\x1b[0m")
  IO.puts(text)
end
