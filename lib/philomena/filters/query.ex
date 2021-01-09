defmodule Philomena.Filters.Query do
  alias Philomena.Search.Parser

  defp user_id_transform(_ctx, data) do
    case Integer.parse(data) do
      {int, _rest} ->
        {
          :ok,
          %{
            bool: %{
              must: [
                %{term: %{public: true}},
                %{term: %{user_id: int}}
              ]
            }
          }
        }

      _err ->
        {:error, "Unknown `user_id' value."}
    end
  end

  defp creator_transform(_ctx, data) do
    {
      :ok,
      %{
        bool: %{
          must: [
            %{term: %{public: true}},
            %{
              bool: %{
                should: [
                  %{term: %{creator: data}},
                  %{wildcard: %{creator: data}}
                ]
              }
            }
          ]
        }
      }
    }
  end

  defp user_my_transform(%{user: %{id: id}}, "filters"),
       do: {:ok, %{term: %{user_id: id}}}

  defp user_my_transform(_ctx, _value),
       do: {:error, "Unknown `my' value."}

  defp anonymous_fields do
    [
      int_fields: ~W(id spoilered_count hidden_count),
      date_fields: ~W(created_at),
      ngram_fields: ~W(name description),
      bool_fields: ~W(system),
      custom_fields: ~W(creator user_id),
      default_field: {"name", :ngram},
      transforms: %{
        "user_id" => &user_id_transform/2,
        "creator" => &creator_transform/2
      },
      aliases: %{"title" => "name", "maintainer" => "creator"}
    ]
  end

  defp user_fields do
    fields = anonymous_fields()

    Keyword.merge(fields,
      custom_fields: fields[:custom_fields] ++ ~W(my),
      transforms: Map.merge(fields[:transforms], %{"my" => &user_my_transform/2})
    )
  end

  defp moderator_fields do
    fields = user_fields()
  end

  defp parse(fields, context, query_string) do
    fields
    |> Parser.parser()
    |> Parser.parse(query_string, context)
  end

  def compile(user, query_string) do
    query_string = query_string || ""

    case user do
      nil ->
        parse(anonymous_fields(), %{user: nil}, query_string)

      %{role: role} when role in ~W(user assistant) ->
        parse(user_fields(), %{user: user}, query_string)

      %{role: role} when role in ~W(moderator admin) ->
        parse(moderator_fields(), %{user: user}, query_string)

      _ ->
        raise ArgumentError, "Unknown user role."
    end
  end
end
