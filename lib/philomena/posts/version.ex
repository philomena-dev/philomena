defmodule Philomena.Posts.Version do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Posts.Post
  alias Philomena.Users.User

  schema "post_versions" do
    belongs_to :post, Post
    belongs_to :user, User
    field :body, :string
    field :edit_reason, :string
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(post_version, post, user, attrs) do
    post_version
    |> cast(attrs, [:body, :edit_reason, :created_at])
    |> put_assoc(:post, post)
    |> put_assoc(:user, user)
    |> validate_required([:post, :user, :body, :created_at])
  end
end
