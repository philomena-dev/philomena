defmodule PhilomenaWeb.Image.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: true
  alias Philomena.Test
  alias Philomena.UsersFixtures
  import PhilomenaWeb.Test.TagChanges

  setup ctx do
    # We need a verified user, because it bypasses the rate limits check
    user = UsersFixtures.user_fixture(%{confirmed: true, verified: true})
    %{conn: log_in_user(ctx.conn, user), user: user}
  end

  test "POST /image/{N}/tags", %{conn: conn, user: user} do
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
        "Image(1): [a 1] [b 1] [safe 1] [c 1] [d 1] [e 1]",
        "TagChange(1): +[c 1] +[d 1] +[e 1]"
      ]
    )

    ctx = update_image_tags(ctx, add: ["f", "g"], remove: ["a", "d"])

    snap = snap(ctx)

    assert_value(
      snap == [
        "Image(1): [b 1] [safe 1] [c 1] [e 1] [f 1] [g 1]",
        "TagChange(2): +[f 1] +[g 1] -[a 0] -[d 0]",
        "TagChange(1): +[c 1] +[d 0] +[e 1]"
      ]
    )

    # Noop should not create a new tag change
    assert snap(update_image_tags(ctx, add: [])) == snap
  end
end
