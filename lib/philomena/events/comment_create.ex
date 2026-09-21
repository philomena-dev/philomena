defmodule Philomena.Events.CommentCreate do
  @enforce_keys [:comment]
  defstruct @enforce_keys

  @type t :: %__MODULE__{comment: Philomena.Comments.Comment.t()}
end
