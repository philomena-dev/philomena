defmodule Philomena.Scrapers.Pillowfort do
  # <a ng-href="https://img3.pillowfort.social/posts/60c27cdc99d9e737abc1.jpg" target="_blank">
  @url_regex ~r|\Ahttps?://[-a-z0-9.]+.pillowfort\.social/posts/[0-9]+\z| # probly'd fail for https://pillowfort...
  @post_regex ~r|\Ahttps?://[-a-z0-9.]+.pillowfort\.social/posts/([0-9]+)\z|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [post_id] = Regex.run(@post_regex, url, capture: :all_but_first)

    api_url = "https://www.pillowfort.social/posts/#{post_id}/json"

    Philomena.Http.get(api_url)
    |> json!()
    |> process_response!(url)
  end

  defp json!({:ok, %Tesla.Env{body: body, status: 200}}),
    do: Jason.decode!(body)

  defp process_response!(postJson, url) do
    images =
      postJson["media"]
      |> Enum.map(
        &%{
          url: &1["url"],
          camo_url: Camo.Image.image_url(&1["url"])
        }
      )
    
    %{
      source_url: url,
      author_name: postJson["username"],
      description: postJson["title"] <> "\n----\n" <> postJson["content"],
      images: images
    }
  end
  
end
