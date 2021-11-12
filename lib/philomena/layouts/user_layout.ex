defmodule Philomena.Layouts.UserLayout do
  use Ecto.Schema

  alias Philomena.Users.User
  alias Philomena.Users.Role
  alias Philomena.Filters.Filter

  @primary_key false
  schema "user_layouts" do
    field :unread_notification_count, :integer
    field :conversation_count, :integer
    belongs_to :user, User

    embeds_many :my_filters, Filter
    embeds_many :recent_filters, Filter
    embeds_many :roles, Role
  end
end
