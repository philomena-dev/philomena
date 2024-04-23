defmodule Philomena.Scrapers.Pixiv do
  @url_regex ~r|\Ahttps?://pixiv\.net/en/artworks/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [_, submission_id] = Regex.run(@url_regex, url, capture: :all)
    api_url = "https://www.pixiv.net/touch/ajax/illust/details?illust_id=#{submission_id}"
    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    submission = Jason.decode!(body)

    description = submission["illust_details"]["comment"]
    |> HtmlSanitizeEx.strip_tags()
    |> String.replace(~r/  +/, " ")
    |> String.replace(~r/\n \n +/, "\n")
    |> String.replace(~r/\n /, "\n")
    |> String.trim()

    %{
      source_url: url,
      author_name: submission["author_details"]["user_account"],
      description: description,
      images: [
        %{
          url: "#{submission["illust_details"]["manga_a"]["url_big"]}",
          camo_url: Camo.Image.image_url(submission["illust_details"]["manga_a"]["url"])
        }
      ]
    }
  end
end
