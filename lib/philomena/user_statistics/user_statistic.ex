defmodule Philomena.UserStatistics.UserStatistic do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User

  @primary_key false

  schema "user_statistics" do
    belongs_to :user, User, primary_key: true
    field :day, :integer, default: 0, primary_key: true
    field :uploads, :integer, default: 0
    field :votes_cast, :integer, default: 0
    field :comments_posted, :integer, default: 0
    field :metadata_updates, :integer, default: 0
    field :images_favourited, :integer, default: 0
    field :forum_posts, :integer, default: 0
    field :topics, :integer, default: 0
  end

  @doc false
  def changeset(user_statistic, attrs) do
    user_statistic
    |> cast(attrs, [
      :uploads,
      :votes_cast,
      :comments_posted,
      :metadata_updates,
      :images_favourited,
      :forum_posts,
      :topics
    ])
  end
end
