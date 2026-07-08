defmodule PhilomenaWeb.ImageControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.CommentsFixtures
  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures

  alias PhilomenaQuery.SearchHelpers
  alias Philomena.Images.Image
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  setup do
    SearchHelpers.recreate_index!(Image)
    # :show and :new render the quick tag table, which queries the tags index
    # (TagView.lookup_quick_tags/1) the first time it is built in a test run.
    SearchHelpers.recreate_index!(Tag)
    :ok
  end

  describe "GET /images" do
    test "lists images for anonymous users", %{conn: conn} do
      image = image_fixture(created_at: hours_ago(1))
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      assert response =~ "Images - Derpibooru"
      assert response =~ ~p"/images/#{image.id}"
    end

    # NOTE: ImageLoader.default_query hides images uploaded less than three
    # minutes ago from anonymous users (delay_home_images?/1).
    test "hides just-uploaded images from anonymous users", %{conn: conn} do
      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      refute response =~ ~p"/images/#{image.id}"
    end

    # NOTE: the delay also applies to logged-in users by default
    # (User.delay_home_images defaults to true).
    test "hides just-uploaded images from logged-in users with default settings", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      refute response =~ ~p"/images/#{image.id}"
    end

    test "shows just-uploaded images to users who disabled the upload delay", %{conn: conn} do
      user =
        confirmed_user_fixture()
        |> Ecto.Changeset.change(delay_home_images: false)
        |> Repo.update!()

      conn = log_in_user(conn, user)

      image = image_fixture()
      SearchHelpers.reindex_all!(Image)

      conn = get(conn, ~p"/images")
      response = html_response(conn, 200)

      assert response =~ ~p"/images/#{image.id}"
    end
  end

  describe "GET /images/:id" do
    test "renders an image for anonymous users", %{conn: conn} do
      image = image_fixture(description: "An image *described* in markdown.")
      _comment = comment_fixture(image, nil, %{"body" => "Test image comment body"})

      conn = get(conn, ~p"/images/#{image}")
      response = html_response(conn, 200)

      assert response =~ "##{image.id} - safe - Derpibooru"
      assert response =~ "An image <em>described</em> in markdown."
      assert response =~ "Test image comment body"
    end

    test "renders an image for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      image = image_fixture()

      conn = get(conn, ~p"/images/#{image}")

      assert html_response(conn, 200) =~ "##{image.id} - safe - Derpibooru"
    end

    test "renders the deleted page for a hidden image", %{conn: conn} do
      image = image_fixture(hidden_from_users: true)

      conn = get(conn, ~p"/images/#{image}")

      assert html_response(conn, 200) =~ "This image has been deleted"
    end

    test "redirects a merged duplicate to its target", %{conn: conn} do
      target = image_fixture()
      duplicate = image_fixture(hidden_from_users: true, duplicate_id: target.id)

      conn = get(conn, ~p"/images/#{duplicate}")

      assert redirected_to(conn) == ~p"/images/#{target}"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "has been marked a duplicate of the image below"
    end

    test "redirects to / for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/images/999999999")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "crashes on a non-integer id", %{conn: conn} do
      assert_raise Ecto.Query.CastError, ~r/cannot be cast to type :id/, fn ->
        get(conn, ~p"/images/not-a-number")
      end
    end

    test "renders an image via the /:id shorthand route", %{conn: conn} do
      image = image_fixture()

      conn = get(conn, "/#{image.id}")

      assert html_response(conn, 200) =~ "##{image.id} - safe - Derpibooru"
    end
  end

  describe "GET /images/new" do
    test "renders the upload form for anonymous users", %{conn: conn} do
      conn = get(conn, ~p"/images/new")

      assert html_response(conn, 200) =~ "New Image - Derpibooru"
    end

    test "renders the upload form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/images/new")

      assert html_response(conn, 200) =~ "New Image - Derpibooru"
    end

    test "redirects banned users back", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = get(conn, ~p"/images/new")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
    end
  end

  describe "POST /images" do
    test "creates an image from a logged-in upload", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "safe, solo, pony",
            "description" => "An uploaded image"
          }
        })

      image = Repo.get_by!(Image, description: "An uploaded image")
      assert image.user_id == user.id
      assert redirected_to(conn) == ~p"/images/#{image}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Image created successfully."

      await_async_upload()
    end

    test "creates an image from an anonymous upload", %{conn: conn} do
      conn =
        conn
        |> put_unique_ip()
        |> post(~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "safe, solo, pony",
            "description" => "An anonymously uploaded image"
          }
        })

      image = Repo.get_by!(Image, description: "An anonymously uploaded image")
      assert image.user_id == nil
      assert redirected_to(conn) == ~p"/images/#{image}"

      await_async_upload()
    end

    test "re-renders the upload form on a validation failure", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{
            "image" => png_upload(),
            "tag_input" => "solo"
          }
        })

      # NOTE: the failure branch re-renders new.html without the :title
      # assign, so pin page content rather than the title.
      response = html_response(conn, 200)
      assert response =~ "Upload a file from your computer"
      assert Repo.aggregate(Image, :count) == 0
    end

    test "re-renders the upload form without a file", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{"tag_input" => "safe, solo, pony"}
        })

      assert html_response(conn, 200) =~ "Upload a file from your computer"
      assert Repo.aggregate(Image, :count) == 0
    end

    test "redirects banned users back", %{conn: conn} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn =
        post(conn, ~p"/images", %{
          "image" => %{"image" => png_upload(), "tag_input" => "safe, solo, pony"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned."
      assert Repo.aggregate(Image, :count) == 0
    end
  end

  # A successful :create spawns an unsupervised upload process
  # (Images.async_upload/2) that writes to the Repo; wait for it to exit
  # before the test ends so it doesn't retry with OwnershipError for the
  # rest of the suite (same recipe as the API image tests).
  defp await_async_upload do
    test_pid = self()

    for pid <- Process.list(), Process.info(pid, :parent) == {:parent, test_pid} do
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        5_000 -> raise "async upload process #{inspect(pid)} did not exit"
      end
    end

    :ok
  end

  # LimitPlug keys anonymous uploads by conn.remote_ip in Valkey, which is
  # shared across the whole test run — give each anonymous write its own
  # address.
  defp put_unique_ip(conn) do
    n = System.unique_integer([:positive])
    %{conn | remote_ip: {10, rem(div(n, 65536), 256), rem(div(n, 256), 256), rem(n, 256)}}
  end

  defp hours_ago(hours) do
    DateTime.utc_now()
    |> DateTime.add(-hours * 3600, :second)
    |> DateTime.truncate(:second)
  end
end
