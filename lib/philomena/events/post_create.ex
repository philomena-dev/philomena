defmodule Philomena.Events.PostCreate do
  @enforce_keys [:post, :topic, :forum]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          post: Philomena.Posts.Post.t(),
          topic: Philomena.Topics.Topic.t(),
          forum: Philomena.Forums.Forum.t()
        }
end
