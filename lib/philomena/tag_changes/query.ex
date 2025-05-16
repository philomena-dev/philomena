defmodule Philomena.TagChanges.Query do
  alias PhilomenaQuery.Parse.Parser

  defp user_my_transform(%{user: %{id: id}}, "changes"),
    do: {:ok, %{term: %{true_user_id: id}}}

  defp user_my_transform(_ctx, _value),
    do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id tags_count added_tags_count removed_tags_count),
      numeric_fields: ~W(user_id image_id tag_ids added_tag_ids removed_tag_ids),
      date_fields: ~W(created_at),
      literal_fields: ~W(user tags added_tags removed_tags),
      bool_fields: ~W(anonymous),
      default_field: {"tags", :term},
      aliases: %{
        "added" => "added_tags",
        "removed" => "removed_tags",
        "added_count" => "added_tags_count",
        "removed_count" => "removed_tags_count",
        "added_id" => "added_tag_ids",
        "removed_id" => "removed_tag_ids",
        "tag_id" => "tag_ids",
        "tag" => "tags"
      }
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: ~W(my),
      transforms: %{"my" => &user_my_transform/2}
    )
  end

  defp moderator_fields do
    fields = user_fields()

    Keyword.merge(fields,
      numeric_fields: fields[:numeric_fields] ++ ~W(true_user_id),
      literal_fields: fields[:literal_fields] ++ ~W(true_user fingerprint),
      ip_fields: ~W(ip)
    )
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.new()
    |> Parser.parse(query_string, context)
  end

  defp fields_for(nil), do: anonymous_fields()
  defp fields_for(%{role: role}) when role in ~W(user assistant), do: user_fields()
  defp fields_for(%{role: role}) when role in ~W(moderator admin), do: moderator_fields()
  defp fields_for(_), do: raise(ArgumentError, "Unknown user role.")

  def compile(query_string, opts \\ []) do
    user = Keyword.get(opts, :user)

    parse(fields_for(user), %{user: user}, query_string)
  end
end
