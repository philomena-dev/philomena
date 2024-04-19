defmodule Philomena.Scrapers.Inkbunny do
  @url_regex ~r|\Ahttps?://inkbunny.net/s/([\d]+)/?|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [submission_id] = Regex.run(@url_regex, url, capture: :last)

    api_url = "https://inkbunny.net/api_submissions.php?show_description=yes&sid=#{inkbunny_sid()}&submission_ids=#{submission_id}"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    json = Jason.decode!(body)
    submission = json["submissions"]

    images = submission["files"]["file_url_full"]

    %{
      source_url: submission["url"],
      author_name: submission["username"],
      description: submission["description"],
      images: images
    }
  end
  defp inkbunny_sid do
    Application.get_env(:philomena, :inkbunny_sid)
  end
end
