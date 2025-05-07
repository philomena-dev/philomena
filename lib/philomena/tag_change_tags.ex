defmodule Philomena.TagChangeTags do
  @moduledoc """
  The TagChanges context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo
  alias Philomena.TagChanges.TagChangeTag

  def get_tag_change_tag!(id), do: Repo.get!(TagChangeTag, id)
end
