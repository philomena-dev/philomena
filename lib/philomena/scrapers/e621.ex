defmodule Philomena.Scrapers.E621 do
  @url_regex ~r|\Ahttps?://e621\.net/posts/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    api_url = "#{url}.json"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    json = Jason.decode!(body)
    submission = json["post"]

    %{
      source_url: url,
      author_name: hd(submission["tags"]["artist"]),
      description: submission["description"],
      images: [%{
        url: "#{submission["file"]["url"]}",
        camo_url: Camo.Image.image_url(submission["file"]["url"])
      }]
    }
  end
end
