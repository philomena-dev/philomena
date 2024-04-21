defmodule Philomena.Scrapers.Inkbunny do
def match_submission_id("https://inkbunny.net/s/" <> id), do: id
def match_submission_id(_), do: nil

iex(1)> Test.match_submission_id("test")
nil
iex(2)> Test.match_submission_id("https://inkbunny.net/s/123456789")
"123456789"
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
