defmodule Philomena.Comments.Version do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Comments.Comment
  alias Philomena.Users.User

  schema "comment_versions" do
    belongs_to :comment, Comment
    belongs_to :user, User
    field :body, :string
    field :edit_reason, :string
    field :index, :integer, virtual: true
    timestamps(inserted_at: :created_at, updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(comment_version, comment, user, attrs) do
    comment_version
    |> cast(attrs, [:body, :edit_reason, :created_at])
    |> put_assoc(:comment, comment)
    |> put_assoc(:user, user)
    |> validate_required([:comment, :user, :body, :created_at])
  end
end
