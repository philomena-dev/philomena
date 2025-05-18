defmodule PhilomenaWeb.Image.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.Test, as: WebTest
  alias Philomena.Test
  alias Philomena.UsersFixtures

  setup ctx do
    # We need a verified user, because it bypasses the rate limits check
    user = UsersFixtures.user_fixture(%{confirmed: true, verified: true})
    %{conn: log_in_user(ctx.conn, user), user: user}
  end

  describe "POST /image/{N}/tags" do
    test "add/remove combinations", %{conn: conn, user: user} do
      ctx = %{
        conn: conn,
        image:
          Test.Images.create_image(user, %{
            "tag_input" => "safe,a,b"
          })
      }

      ctx = update_image_tags(ctx, add: ["c", "d", "e"])

      assert_value(
        snap(ctx) == [
          "Image #1: [a 1] [b 1] [safe 1] [c 1] [d 1] [e 1]",
          "TagChange #1: +[c 1] +[d 1] +[e 1]"
        ]
      )

      ctx = update_image_tags(ctx, add: ["f", "g"], remove: ["a", "d"])

      snap = snap(ctx)

      assert_value(
        snap == [
          "Image #1: [b 1] [safe 1] [c 1] [e 1] [f 1] [g 1]",
          "TagChange #2: +[f 1] +[g 1] -[a 0] -[d 0]",
          "TagChange #1: +[c 1] +[d 0] +[e 1]"
        ]
      )

      # Noop should not create a new tag change
      assert snap(update_image_tags(ctx, add: [])) == snap
    end

    defp update_image_tags(ctx, diff) do
      conn =
        WebTest.Images.update_image_tags(ctx.conn, ctx.image, diff)

      image = Test.Images.load_image!(ctx.image.id, preload: [:tags])

      %{
        conn: conn,
        image: image
      }
    end

    defp snap(ctx) do
      image_tags =
        ctx.image.tags
        |> Enum.map(fn tag -> "[#{tag.name} #{tag.images_count}]" end)
        |> Enum.join(" ")

      tag_changes =
        ctx.image.id
        |> Test.TagChanges.load_tag_changes_by_image_id()
        |> Enum.map(&Test.TagChanges.to_snap/1)

      ["Image ##{ctx.image.id}: #{image_tags}"] ++ tag_changes
    end
  end
end
