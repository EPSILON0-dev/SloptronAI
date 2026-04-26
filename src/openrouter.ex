defmodule SloptronAI.OpenRouter do
  @moduledoc false

  @spec request(SloptronAI.Config, binary(), binary(), Map) ::
          Jason.Value.t() | nil
  def request(config, query, model, props) do
    case Req.post(
           url: config.openrouter_api_url <> "/responses",
           headers: [
             Authorization: "Bearer " <> config.openrouter_api_key,
             "Content-Type": "application/json"
           ],
           json: Map.merge(%{input: query, model: model}, props)
         ) do
      {:ok, resp} -> resp.body
      {:error, reason} -> raise "Request failed: #{reason}"
    end
  end

  @spec request_streamed(SloptronAI.Config, binary(), binary(), Map, (binary() -> nil)) ::
          Jason.Value.t() | nil
  def request_streamed(config, query, model, props, on_chunk) do
    case Req.post(
           url: config.openrouter_api_url <> "/responses",
           headers: [
             Authorization: "Bearer " <> config.openrouter_api_key,
             "Content-Type": "application/json"
           ],
           json: Map.merge(%{input: query, model: model, stream: true}, props),
           into: fn {:data, chunk}, {req, resp} ->
             new_resp =
               chunk
               |> IO.iodata_to_binary()
               |> String.split("\n")
               |> Enum.reduce(resp, fn line, resp ->
                 case line |> String.trim() |> String.trim_leading("data: ") |> Jason.decode() do
                   {:ok, chunk_json} ->
                     case chunk_json |> Map.get("type") do
                       "response.output_text.delta" ->
                         chunk_json |> Map.get("delta") |> on_chunk.()
                         resp

                       "response.completed" ->
                         put_in(resp.private[:completed], chunk_json)

                       _ ->
                         resp
                     end

                   _ ->
                     resp
                 end
               end)

             {:cont, {req, new_resp}}
           end
         ) do
      {:ok, resp} -> resp.private[:completed] |> Map.get("response")
      {:error, reason} -> raise "Request failed: #{reason}"
    end
  end

  @spec get_cost(Req.Response) :: float()
  def get_cost(resp) do
    resp |> Map.get("usage") |> Map.get("cost")
  end

  @spec get_response(Req.Response) :: binary()
  def get_response(resp) do
    resp
    |> Map.get("output")
    |> List.first()
    |> Map.get("content")
    |> List.first()
    |> Map.get("text")
  end
end
