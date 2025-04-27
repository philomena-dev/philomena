defmodule Philomena.Galleries.Query do
  alias PhilomenaQuery.Parse.Parser

  defp fields do
    [
      int_fields: ~W(id image_count watcher_count),
      numeric_fields: ~W(user_id image_ids thumbnail_id),
      literal_fields: ~W(title user),
      date_fields: ~W(created_at updated_at),
      ngram_fields: ~W(description spoiler_warning),
      default_field: {"title", :term},
      aliases: %{
        "user_id" => "creator_id",
        "user" => "creator"
      }
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.new()
    |> Parser.parse(query_string)
  end
end
