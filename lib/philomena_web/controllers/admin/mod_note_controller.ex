defmodule PhilomenaWeb.Admin.ModNoteController do
  use PhilomenaWeb, :controller

  alias PhilomenaWeb.MarkdownRenderer
  alias Philomena.ModNotes.ModNote
  alias Philomena.ModNotes

  plug :load_and_authorize_resource, model: ModNote

  def index(conn, params) do
    pagination = conn.assigns.scrivener
    renderer = &MarkdownRenderer.render_collection(&1, conn)

    mod_notes =
      case params do
        %{"notable_type" => type, "notable_id" => id} ->
          ModNotes.list_mod_notes_by_notable_type_and_id(type, id, renderer, pagination)

        _ ->
          ModNotes.list_mod_notes(renderer, pagination)
      end

    render(conn, "index.html", title: "Admin - Mod Notes", mod_notes: mod_notes)
  end

  def new(conn, %{"notable_type" => type, "notable_id" => id}) do
    changeset = ModNotes.change_mod_note(%ModNote{notable_type: type, notable_id: id})
    render(conn, "new.html", title: "New Mod Note", changeset: changeset)
  end

  def create(conn, %{"mod_note" => mod_note_params}) do
    case ModNotes.create_mod_note(conn.assigns.current_user, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully created mod note.")
        |> redirect(to: ~p"/admin/mod_notes")

      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, _params) do
    changeset = ModNotes.change_mod_note(conn.assigns.mod_note)
    render(conn, "edit.html", title: "Editing Mod Note", changeset: changeset)
  end

  def update(conn, %{"mod_note" => mod_note_params}) do
    case ModNotes.update_mod_note(conn.assigns.mod_note, mod_note_params) do
      {:ok, _mod_note} ->
        conn
        |> put_flash(:info, "Successfully updated mod note.")
        |> redirect(to: ~p"/admin/mod_notes")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    {:ok, _mod_note} = ModNotes.delete_mod_note(conn.assigns.mod_note)

    conn
    |> put_flash(:info, "Successfully deleted mod note.")
    |> redirect(to: ~p"/admin/mod_notes")
  end
end
