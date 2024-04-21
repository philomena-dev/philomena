defmodule Philomena.Scrapers.Furaffinity do
  @url_regex ~r|\Ahttps?://www.furaffinity\.net/view/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [_, submission_id] = Regex.run(@url_regex, url, capture: :all)
    api_url = "https://faexport.spangle.org.uk/submission/#{submission_id}.json"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    submission = Jason.decode!(body)

    %{
      source_url: url,
      author_name: submission["name"],
      description: submission["description"],
      images: [
        %{
          url: "#{submission["download"]}",
          camo_url: Camo.Image.image_url(submission["thumbnail"])
        }
      ]
    }
  end
end
