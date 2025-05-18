defmodule PhilomenaWeb.Test.Images do
  alias Philomena.Images.Image

  import Phoenix.ConnTest

  use ExUnit.Case

  @endpoint PhilomenaWeb.Endpoint

  use PhilomenaWeb, :verified_routes

  @type tags_diff :: [
          add: [String.t()],
          remove: [String.t()]
        ]

  @spec update_image_tags(Plug.Conn.t(), Image.t(), tags_diff()) ::
          Plug.Conn.t()
  def update_image_tags(conn, image, diff) do
    added_tags = Keyword.get(diff, :add, [])
    removed_tags = Keyword.get(diff, :remove, [])
    current_tags = image.tags |> Enum.map(& &1.name)

    for tag <- added_tags do
      assert tag not in current_tags
    end

    new_tags =
      current_tags
      |> Enum.reject(&(&1 in removed_tags))
      |> Enum.concat(added_tags)

    conn =
      conn
      |> post(~p"/images/#{image.id}/tags", %{
        "_method" => "put",
        "image" => %{
          "old_tag_input" => current_tags |> Enum.join(", "),
          "tag_input" => new_tags |> Enum.join(", ")
        }
      })

    if conn.status != 200 do
      raise "Failed to update image tags (#{conn.status}): #{inspect(conn.assigns.flash)}"
    end

    response = response_content_type(conn, :html)

    # `help-block` is returned to display an error to the user
    assert not String.contains?(response, "class=\"help-block\"")

    for tag <- new_tags |> Enum.reject(&(not String.starts_with?(&1, "-"))) do
      assert response =~ tag
    end

    for tag <- new_tags |> Enum.filter(&String.starts_with?(&1, "-")) do
      assert response =~ tag |> String.replace_leading("-", "")
    end

    conn
  end
end
