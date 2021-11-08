defmodule Philomena.Layouts.Layout do
  use Ecto.Schema

  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.Forums.Forum

  @primary_key false
  schema "layouts" do
    field :artist_link_count, :integer
    field :channel_count, :integer
    field :dnp_entry_count, :integer
    field :duplicate_report_count, :integer
    field :report_count, :integer

    embeds_many :site_notices, SiteNotice
    embeds_many :forums, Forum
  end
end
