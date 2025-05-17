defmodule PhilomenaWeb.TagChange.RevertControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias Philomena.Users
  alias Philomena.TagChanges
  alias Philomena.Images
  alias Philomena.Images.Image
  alias Philomena.Repo
  import Philomena.UsersFixtures
  import Philomena.ImagesFixtures
  import Ecto.Query

  setup :register_and_log_in_user

  describe "POST /tag_changes/revert" do
    test "reverts tag changes", %{conn: conn, user: user} do
      # TODO: make the user authorized, otherwise the test may fail due to
      # exceeding the rate limits for tag changes

      image = image_fixture(user)

      {conn, image} =
        update_tags(conn, image, add: ["tag3", "tag4"])

      assert_value(load_tag_changes(image) == [["+tag3 (images: 1)", "+tag4 (images: 1)"]])

      {conn, image} = update_tags(conn, image, remove: ["tag3", "tag4"])

      assert_value(
        load_tag_changes(image) == [
          ["-tag3 (images: 0)", "-tag4 (images: 0)"],
          ["+tag3 (images: 0)", "+tag4 (images: 0)"]
        ]
      )

      {_conn, image} = update_tags(conn, image, add: ["tag3"], remove: ["tag2"])

      assert_value(
        load_tag_changes(image) == [
          ["+tag3 (images: 1)", "-tag2 (images: 0)"],
          ["-tag3 (images: 1)", "-tag4 (images: 0)"],
          ["+tag3 (images: 1)", "+tag4 (images: 0)"]
        ]
      )
    end
  end

  defp load_tag_changes(image) do
    TagChanges.load(
      %{
        field: :image_id,
        value: image.id
      },
      nil
    ).entries
    |> Enum.map(&tag_change_to_snap/1)
  end

  defp tag_change_to_snap(%TagChanges.TagChange{} = tag_change) do
    tag_change.tags
    |> Enum.map(fn %{tag: tag, added: added} ->
      "#{if(added, do: "+", else: "-")}#{tag.name} (images: #{tag.images_count})"
    end)
  end

  defp update_tags(conn, image, diff) do
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

    response = html_response(conn, 200)

    # `help-block` is returned to display an error to the user
    assert not String.contains?(response, "class=\"help-block\"")

    for tag <- new_tags |> Enum.reject(&(not String.starts_with?(&1, "-"))) do
      assert response =~ tag
    end

    for tag <- new_tags |> Enum.filter(&String.starts_with?(&1, "-")) do
      assert response =~ tag |> String.replace_leading("-", "")
    end

    image =
      Image
      |> where(id: ^image.id)
      |> preload([:tags])
      |> Repo.one()

    {conn, image}
  end
end
