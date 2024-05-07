defmodule Philomena.Scrapers.Baraag do
  @url_regex ~r|\Ahttps?://baraag.net/@[A-Za-z\d_]+/([\d]+)/?|
  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [user, status_id] = Regex.run(@url_regex, url, capture: :all)

    api_url = "https://baraag.net/api/v1/statuses/#{status_id}"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    toot = Jason.decode!(body)

    images =
      Enum.map(toot["media_attachments"], fn p ->
        %{
          url: ["url"],
          camo_url: Camo.Image.image_url(p["preview_url"])
        }
      end)

    %{
      source_url: toot["url"],
      author_name: toot["account"]["username"],
      description: toot["content"],
      images: images
    }
  end
end