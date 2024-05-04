defmodule Philomena.Scrapers.Derpibooru do
  @url_regex ~r/\A(https\:\/\/derpibooru\.org\/images\/([0-9]+))(?:.+)?/

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [_, url, submission_id] = Regex.run(@url_regex, url, capture: :all)

    api_url =
      "https://derpibooru.org/api/v1/json/images/#{submission_id}"

    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    json = Jason.decode!(body)
    submission = json["image"]

    tags = submission["tags"]

    %{
      source_url: url,
      tags: tags,
      sources: submission["source_urls"],
      description: submission["description"],
      images: [
        %{
          url: "#{submission["representations"]["full"]}",
          camo_url: Camo.Image.image_url(submission["representations"]["medium"])
        }
      ]
    }
  end
end
