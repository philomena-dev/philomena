defmodule Philomena.Test.Tags do
  alias Philomena.Tags.Tag

  def snap(%Tag{} = tag) do
    "[#{tag.name} #{tag.images_count}]"
  end
end
