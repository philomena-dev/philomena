defmodule Philomena.Scrapers.Inkbunny do
  @url_regex ~r|\Ahttps?://inkbunny\.net/s/([0-9]+)|

  @spec can_handle?(URI.t(), String.t()) :: true | false
  def can_handle?(_uri, url) do
    String.match?(url, @url_regex)
  end

  def scrape(_uri, url) do
    [_, submission_id] = Regex.run(@url_regex, url, capture: :all)

    api_url =
      "https://inkbunny.net/api_submissions.php?show_description=yes&sid=#{inkbunny_sid()}&submission_ids=#{submission_id}"

    {:ok, %Tesla.Env{status: 200, body: body}} = Philomena.Http.get(api_url)

    json = Jason.decode!(body)
    [submission] = json["submissions"]

    rating = if submission["rating_name"] == "General", do: "safe"
    r = submission["ratings"]

    rating =
      cond do
        r == [] ->
          rating

        Enum.find(r, fn x -> x["name"] == "Strong Violence" end) ->
          false

        Enum.find(r, fn x -> x["name"] == "Sexual Themes" end) ->
          "explicit"

        Enum.find(r, fn x -> x["name"] == "Violence" end) ->
          "grimdark"

        Enum.find(r, fn x -> x["name"] == "Nudity" end) ->
          "nude only"
      end

    if rating do
      description = "##\s#{submission["title"]}\n#{submission["description"]}"

      tags =
        for x <- submission["keywords"], x["contributed"] == "f" do
          x["keyword_name"]
        end

      images =
        for x <- submission["files"] do
          %{
            url: "#{x["file_url_full"]}",
            camo_url: Camo.Image.image_url(x["file_url_screen"])
          }
        end

      %{
        source_url: url,
        author_name: submission["username"],
        description: description,
        tags: [rating | tags],
        images: images
      }
    else
      %{errors: ["Requested image does not have an acceptable rating for submission."]}
    end
  end

  defp inkbunny_sid do
    Application.get_env(:philomena, :inkbunny_sid)
  end
end
