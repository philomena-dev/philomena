defmodule PhilomenaWeb.Test.TagChanges do
  alias Philomena.Images.Image
  alias Philomena.Test

  import Phoenix.ConnTest

  use ExUnit.Case

  @endpoint PhilomenaWeb.Endpoint

  use PhilomenaWeb, :verified_routes

  @doc "Context of the test"
  @type ctx :: %{
          conn: Plug.Conn.t(),
          image: Image.t()
        }

  @type tags_diff :: [
          add: [String.t()],
          remove: [String.t()]
        ]

  @spec update_image_tags(ctx(), tags_diff()) :: ctx()
  def update_image_tags(ctx, diff) do
    added_tags = Keyword.get(diff, :add, [])
    removed_tags = Keyword.get(diff, :remove, [])
    current_tags = ctx.image.tags |> Enum.map(& &1.name)

    for tag <- added_tags do
      assert tag not in current_tags
    end

    new_tags =
      current_tags
      |> Enum.reject(&(&1 in removed_tags))
      |> Enum.concat(added_tags)

    conn =
      ctx.conn
      |> post(~p"/images/#{ctx.image.id}/tags", %{
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

    %{
      conn: conn,
      image: Test.Images.load_image!(ctx.image.id, preload: [:tags])
    }
  end

  @spec snap(ctx()) :: any()
  def snap(ctx) do
    tag_changes =
      ctx.image.id
      |> Test.TagChanges.load_tag_changes_by_image_id()
      |> Enum.map(&Test.TagChanges.snap/1)

    [Test.Images.snap(ctx.image) | tag_changes]
  end
end
