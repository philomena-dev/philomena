defmodule PhilomenaWeb.TagChange.RevertControllerTest do
  use PhilomenaWeb.ConnCase
  alias Philomena.Repo
  alias Philomena.Users
  alias Philomena.Test
  import PhilomenaWeb.Test.TagChanges

  # We need a verified user, because it bypasses the rate limits check
  setup ctx do
    register_and_log_in_user(ctx, %{verified: true})
  end

  test "unauthorized", ctx do
    {ctx, first_tag_change} = create_image_with_tag_change(ctx)

    ctx = try_revert_tag_changes(ctx, [first_tag_change.id])

    # The default test user is a regular user, so it's not authorized to
    # revert tag changes
    assert_value(ctx.conn.assigns.flash == %{"error" => "You can't access that page."})

    html_response(ctx.conn, 302)
  end

  describe "authorized" do
    setup ctx do
      {:ok, moderator} =
        ctx.user
        |> Repo.preload([:roles])
        |> Users.update_user(%{"role" => "moderator"})

      put_in(ctx.user, moderator)
    end

    test "noop reverts", ctx do
      {ctx, first_tag_change} = create_image_with_tag_change(ctx)

      ctx = revert_tag_changes(ctx, [first_tag_change.id])

      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 1 tag changes with 1 tags actually updated."
        }
      )

      snap = snap(ctx)

      assert_value(
        snap == [
          "Image(1): [a 1] [b 1] [c 1] [safe 1]",
          "TagChange(2): -[d 0]",
          "TagChange(1): +[d 0]"
        ]
      )

      # Reverting again should be a no-op
      ctx = revert_tag_changes(ctx, [first_tag_change.id])

      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 1 tag changes with 0 tags actually updated."
        }
      )

      tag_changes = Test.TagChanges.load_tag_changes_by_image_id(ctx.image.id)

      assert snap(ctx, tag_changes) == snap

      ctx = revert_tag_changes(ctx, tag_changes |> Enum.map(& &1.id))

      # The last tag change removed the tag, so now it should be re-added again
      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 2 tag changes with 0 tags actually updated."
        }
      )

      tag_changes = Test.TagChanges.load_tag_changes_by_image_id(ctx.image.id)
      snap = snap(ctx, tag_changes)

      assert_value(
        snap ==
          ["Image(1): [a 1] [b 1] [c 1] [safe 1]", "TagChange(2): -[d 0]", "TagChange(1): +[d 0]"]
      )

      # Try to revert the change that was the first. It should be no-op
      # since the tag is already present on the image
      ctx = revert_tag_changes(ctx, [first_tag_change.id])

      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 1 tag changes with 0 tags actually updated."
        }
      )

      assert snap(ctx) == snap

      tag_changes =
        Test.TagChanges.load_tag_changes_by_image_id(ctx.image.id)
        |> Enum.drop(1)

      ctx = revert_tag_changes(ctx, tag_changes |> Enum.map(& &1.id))

      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 1 tag changes with 0 tags actually updated."
        }
      )

      assert snap(ctx) == snap
    end

    test "mixed tag changes reverts", ctx do
      ctx =
        ctx
        |> Test.Images.create_image(%{"tag_input" => "safe,a,b,c"})
        |> update_image_tags(add: ["d", "e"], remove: ["a", "b"])
        |> update_image_tags(add: ["f", "g"], remove: ["c", "d"])
        |> update_image_tags(add: ["h", "i"], remove: ["e", "f"])
        |> update_image_tags(add: ["j"], remove: ["g", "h"])
        |> update_image_tags(add: ["g", "c"])

      tag_changes = Test.TagChanges.load_tag_changes_by_image_id(ctx.image.id)

      ctx = revert_tag_changes(ctx, tag_changes |> Enum.map(& &1.id))

      assert_value(
        ctx.conn.assigns.flash == %{
          "info" => "Successfully reverted 5 tag changes with 5 tags actually updated."
        }
      )

      assert_value(
        snap(ctx) == [
          "Image(1): [safe 1] [c 1] [a 1] [b 1]",
          "TagChange(6): +[a 1] +[b 1] -[g 0] -[i 0] -[j 0]",
          "TagChange(5): +[c 1] +[g 0]",
          "TagChange(4): +[j 0] -[g 0] -[h 0]",
          "TagChange(3): +[h 0] +[i 0] -[e 0] -[f 0]",
          "TagChange(2): +[f 0] +[g 0] -[c 1] -[d 0]",
          "TagChange(1): +[d 0] +[e 0] -[a 1] -[b 1]"
        ]
      )
    end
  end

  defp create_image_with_tag_change(ctx) do
    ctx =
      ctx
      |> Test.Images.create_image(%{"tag_input" => "safe,a,b,c"})
      |> update_image_tags(add: ["d"])

    [tag_change] = Test.TagChanges.load_tag_changes_by_image_id(ctx.image.id)

    {ctx, tag_change}
  end

  defp revert_tag_changes(ctx, tag_change_ids) do
    ctx = try_revert_tag_changes(ctx, tag_change_ids)

    html_response(ctx.conn, 302)

    put_in(ctx.image, Test.Images.load_image!(ctx.image.id, preload: [:tags]))
  end

  defp try_revert_tag_changes(ctx, tag_change_ids) do
    conn = post(ctx.conn, ~p"/tag_changes/revert", %{"ids" => tag_change_ids})

    put_in(ctx.conn, conn)
  end
end
