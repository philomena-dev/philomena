defmodule PhilomenaWeb.Image.Comment.HistoryView do
  use PhilomenaWeb, :view

  def merge_version(comment, version) do
    comment
    |> Map.put(:body, version.body)
    |> Map.put(:edited_at, version.created_at)
    |> Map.put(:edit_reason, version.edit_reason)
  end
end
