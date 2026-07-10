defmodule PhilomenaWeb.Admin.Batch.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures

  alias Philomena.Images.Image
  alias Philomena.Images.Tagging
  alias Philomena.Repo

  describe "PATCH /admin/batch/tags authorization" do
    test "redirects anonymous users to login", %{conn: conn} do
      conn = patch(conn, ~p"/admin/batch/tags", tags: "safe", image_ids: [])
      assert redirected_to(conn) == ~p"/sessions/new"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "must log in"
    end

    test "rejects a regular user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = patch(conn, ~p"/admin/batch/tags", tags: "safe", image_ids: [])
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    # NOTE: :batch_update on Tag has no plain-moderator rule - a moderator is
    # rejected; only admins (or a Tag-admin/batch_update role_map grant) pass.
    test "rejects a plain moderator", %{conn: conn} do
      %{conn: conn} = register_and_log_in_moderator(%{conn: conn})
      conn = patch(conn, ~p"/admin/batch/tags", tags: "safe", image_ids: [])
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end
  end

  describe "PATCH /admin/batch/tags (update)" do
    setup [:register_and_log_in_admin]

    test "adds a tag to the given images and returns the ids as succeeded",
         %{conn: conn} do
      image = image_fixture()
      _tag = tag_fixture(name: "batch-added-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "batch-added-tag",
          image_ids: [to_string(image.id)]
        )

      assert json_response(conn, 200) == %{"succeeded" => [image.id], "failed" => []}

      tag_names =
        image.id
        |> tags_for_image()
        |> Enum.map(& &1.name)

      assert "batch-added-tag" in tag_names
    end

    test "removes a tag prefixed with a minus", %{conn: conn} do
      tag = tag_fixture(name: "batch-removed-tag")
      image = image_fixture(tags: "safe, batch-removed-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "-batch-removed-tag",
          image_ids: [to_string(image.id)]
        )

      assert json_response(conn, 200) == %{"succeeded" => [image.id], "failed" => []}

      tag_names =
        image.id
        |> tags_for_image()
        |> Enum.map(& &1.name)

      refute tag.name in tag_names
    end

    # `succeeded` contains only the ids the batch actually matched; a
    # well-formed id that names no image is reported as failed.
    test "reports unknown image ids as failed", %{conn: conn} do
      _tag = tag_fixture(name: "batch-unknown-id-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "-batch-unknown-id-tag",
          image_ids: ["2000000000"]
        )

      assert json_response(conn, 200) == %{"succeeded" => [], "failed" => [2_000_000_000]}
    end

    # Tag additions are windowed to the matched images just like removals, so
    # the batch commits over the matched subset and the unknown id fails.
    test "adds an existing tag to the matched images and fails the unknown id",
         %{conn: conn} do
      image = image_fixture()
      _tag = tag_fixture(name: "batch-fk-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "batch-fk-tag",
          image_ids: [to_string(image.id), "2000000000"]
        )

      assert json_response(conn, 200) == %{
               "succeeded" => [image.id],
               "failed" => [2_000_000_000]
             }

      tag_names =
        image.id
        |> tags_for_image()
        |> Enum.map(& &1.name)

      assert "batch-fk-tag" in tag_names

      # No tagging row is ever created for the unmatched id.
      refute Repo.exists?(where(Tagging, image_id: 2_000_000_000))
    end

    test "reports a hidden image's id as failed without tagging it", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)
      tag = tag_fixture(name: "batch-hidden-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "batch-hidden-tag",
          image_ids: [to_string(image.id)]
        )

      assert json_response(conn, 200) == %{"succeeded" => [], "failed" => [image.id]}

      # The hidden image never receives the tagging.
      refute Repo.exists?(where(Tagging, image_id: ^image.id, tag_id: ^tag.id))
    end

    # NOTE: a tag list that resolves to zero actual tag changes (here a tag
    # that does not exist) empties the batch, so no image is matched and
    # every id is reported as failed.
    test "reports all ids as failed when the tag list resolves to no tag changes",
         %{conn: conn} do
      image = image_fixture()

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "this-tag-does-not-exist",
          image_ids: [to_string(image.id)]
        )

      assert json_response(conn, 200) == %{"succeeded" => [], "failed" => [image.id]}
    end

    test "works via PUT as well", %{conn: conn} do
      image = image_fixture()
      _tag = tag_fixture(name: "batch-put-tag")

      conn =
        put(conn, ~p"/admin/batch/tags",
          tags: "batch-put-tag",
          image_ids: [to_string(image.id)]
        )

      assert json_response(conn, 200) == %{"succeeded" => [image.id], "failed" => []}
    end

    # NOTE: a non-integer image id can't name an image, so it is now reported in
    # `failed` while the parsable ids still process, rather than raising.
    test "returns a non-integer image id in failed and processes the rest", %{conn: conn} do
      image = image_fixture()
      _tag = tag_fixture(name: "batch-mixed-tag")

      conn =
        patch(conn, ~p"/admin/batch/tags",
          tags: "batch-mixed-tag",
          image_ids: [to_string(image.id), "not-an-integer"]
        )

      assert json_response(conn, 200) == %{
               "succeeded" => [image.id],
               "failed" => ["not-an-integer"]
             }
    end

    # NOTE: a request missing tags (or carrying a non-list image_ids / non-binary
    # tags) no longer matches the primary update/2 clause and now answers 400
    # with empty lists rather than raising.
    test "answers 400 when required params are missing", %{conn: conn} do
      conn = patch(conn, ~p"/admin/batch/tags", image_ids: [])

      assert json_response(conn, 400) == %{"succeeded" => [], "failed" => []}
    end
  end

  defp tags_for_image(image_id) do
    Image
    |> Repo.get(image_id)
    |> Repo.preload(:tags)
    |> Map.fetch!(:tags)
  end
end
