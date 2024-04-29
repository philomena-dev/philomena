defmodule Philomena.Scrapers.Inkbunny do
  @url_regex ~r|\Ahttps?://inkbunny\.net/s/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
[_, submission_id] = Regex.run(@url_regex, url, capture: :all)
    api_url = "https://inkbunny.net/api_submissions.php?show_description=yes&sid=#{inkbunny_sid()}&submission_ids=#{submission_id}"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    json = Jason.decode!(body)
    [submission] = json["submissions"]
    tags = submission["keywords"]["keyword_name"]

    images = for x <- submission["files"] do
      %{
        url: "#{x["file_url_full"]}",
        camo_url: Camo.Image.image_url(x["file_url_preview"])
      }
    end

    %{
      source_url: url,
      tags: tags,
      author_name: submission["username"],
      description: submission["description"],
      images: images
    }
  end
  defp inkbunny_sid do
    Application.get_env(:philomena, :inkbunny_sid)
  end
end
