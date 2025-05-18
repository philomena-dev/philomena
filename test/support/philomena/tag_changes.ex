defmodule Philomena.Test.TagChanges do
  alias Philomena.TagChanges
  alias Philomena.Test

  @spec load_tag_changes_by_image_id(integer()) :: [TagChanges.TagChange.t()]
  def load_tag_changes_by_image_id(image_id) do
    fn page_params ->
      TagChanges.load(
        %{
          field: :image_id,
          value: image_id
        },
        page_params
      )
    end
    |> Test.Pagination.load_all()
  end

  def snap(%TagChanges.TagChange{} = tag_change) do
    suffix =
      tag_change.tags
      |> Enum.map(fn %{tag: tag, added: added} ->
        "#{if(added, do: "+", else: "-")}#{Test.Tags.snap(tag)}"
      end)
      |> Enum.join(" ")

    "TagChange(#{tag_change.id}): #{suffix}"
  end
end
