defmodule PhilomenaWeb.Image.UploaderController do
  use PhilomenaWeb, :controller

  alias Philomena.Images.Image
  alias Philomena.Images
  alias Philomena.Repo

  plug :verify_authorized
  plug :load_resource, model: Image, id_name: "image_id", required: true

  def update(conn, %{"image" => image_params}) when is_map(image_params) do
    case Images.update_uploader(conn.assigns.image, image_params) do
      {:ok, image} ->
        Images.reindex_image(image)

        image = Repo.preload(image, user: [awards: :badge])
        changeset = Images.change_image(image)

        conn
        |> put_view(PhilomenaWeb.ImageView)
        |> moderation_log(details: &log_details/2, data: image)
        |> render("_uploader.html", layout: false, image: image, changeset: changeset)

      {:error, _changeset} ->
        update_failed(conn)
    end
  end

  def update(conn, _params), do: update_failed(conn)

  # The form is submitted over AJAX; a 300 makes `ujs.ts` reload the page so the
  # flash renders.
  defp update_failed(conn) do
    conn
    |> put_flash(:error, "Failed to update uploader!")
    |> send_resp(:multiple_choices, "")
  end

  defp verify_authorized(conn, _opts) do
    if Canada.Can.can?(conn.assigns.current_user, :show, :ip_address) do
      conn
    else
      PhilomenaWeb.NotAuthorizedPlug.call(conn)
    end
  end

  defp log_details(_action, image) do
    %{body: "Changed uploader of image #{image.id}", subject_path: ~p"/images/#{image}"}
  end
end
