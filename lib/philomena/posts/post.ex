defmodule Philomena.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias Philomena.Users.User
  alias Philomena.Topics.Topic
  alias Philomena.Schema.Approval

  schema "posts" do
    belongs_to :user, User
    belongs_to :topic, Topic
    belongs_to :deleted_by, User

    field :body, :string
    field :edit_reason, :string
    field :ip, EctoNetwork.INET
    field :fingerprint, :string
    field :topic_position, :integer
    field :hidden_from_users, :boolean, default: false
    field :anonymous, :boolean, default: false
    field :edited_at, :utc_datetime
    field :deletion_reason, :string, default: ""
    field :destroyed_content, :boolean, default: false
    field :approved, :boolean, default: false

    timestamps(inserted_at: :created_at, type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs, edited_at \\ nil) do
    post
    |> cast(attrs, [:body, :edit_reason])
    |> put_change(:edited_at, edited_at)
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> validate_length(:edit_reason, max: 70, count: :bytes)
    |> Approval.maybe_put_approval(post.user)
  end

  @doc false
  def creation_changeset(post, attrs, attribution) do
    post
    |> cast(attrs, [:body, :anonymous])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(attribution)
    |> Approval.maybe_put_approval(attribution[:user])
    |> Approval.maybe_strip_images(attribution[:user])
  end

  @doc false
  def topic_creation_changeset(post, attrs, attribution, anonymous?) do
    post
    |> change(anonymous: anonymous?)
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 300_000, count: :bytes)
    |> change(attribution)
    |> change(topic_position: 0)
    |> Approval.maybe_put_approval(attribution[:user])
    |> Approval.maybe_strip_images(attribution[:user])
  end

  def hide_changeset(post, attrs, user) do
    post
    |> cast(attrs, [:deletion_reason])
    |> put_change(:hidden_from_users, true)
    |> put_change(:deleted_by_id, user.id)
    |> validate_required([:deletion_reason])
  end

  def unhide_changeset(post) do
    change(post)
    |> put_change(:hidden_from_users, false)
    |> put_change(:deletion_reason, "")
  end

  def destroy_changeset(post) do
    change(post)
    |> put_change(:destroyed_content, true)
    |> put_change(:body, "")
  end

  def approve_changeset(post) do
    change(post)
    |> put_change(:approved, true)
  end
end
