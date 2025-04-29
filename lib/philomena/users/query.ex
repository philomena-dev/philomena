defmodule Philomena.Users.Query do
  alias PhilomenaQuery.Parse.Parser

  # TODO: change `deleted_by_user_id` to numeric
  defp fields do
    [
      int_fields:
        ~W(id forum_posts_count topic_count uploads_count votes_cast_count comments_posted_count metadata_updates_count images_favourited_count),
      date_fields: ~W(created_at confirmed_at locked_at deleted_at),
      literal_fields: ~W(name slug role email deleted_by_user deleted_by_user_id),
      bool_fields: ~W(custom_avatar verified),
      ngram_fields: ~W(description scratchpad personal_title),
      default_field: {"name", :term}
    ]
  end

  def compile(query_string) do
    fields()
    |> Parser.new()
    |> Parser.parse(query_string)
  end
end
