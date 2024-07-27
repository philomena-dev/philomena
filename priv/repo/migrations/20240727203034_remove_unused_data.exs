defmodule Philomena.Repo.Migrations.RemoveUnusedData do
  use Ecto.Migration

  def change do
    # migration tables
    drop table(:old_source_changes)

    # no longer relevant
    drop table(:unread_notifications)
    drop table(:notifications)
    drop table(:user_whitelists)
    drop table(:vpns)

    # dead columns
    alter table(:artist_links) do
      remove :hostname, :string
      remove :path, :string
    end

    alter table(:channels) do
      remove :channel_image, :string
      remove :banner_image, :string
      remove :tags, :string
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
      remove :viewer_minutes_today, :integer, default: 0, null: false
      remove :viewer_minutes_thisweek, :integer, default: 0, null: false
      remove :viewer_minutes_thismonth, :integer, default: 0, null: false
      remove :total_viewer_minutes, :integer, default: 0, null: false
      remove :remote_stream_id, :integer
      remove :thumbnail_url, :string, default: ""
    end

    alter table(:comments) do
      remove :referrer, :string, default: ""
      remove :user_agent, :string, default: ""
      remove :name_at_post_time, :string
      remove :body_textile, :string, default: "", null: false
    end

    alter table(:commission_items) do
      remove :description_textile, :string
      remove :add_ons_textile, :string
    end

    alter table(:commissions) do
      remove :information_textile, :string
      remove :contact_textile, :string
      remove :will_create_textile, :string
      remove :will_not_create_textile, :string
    end

    alter table(:dnp_entries) do
      remove :conditions_textile, :string, default: "", null: false
      remove :reason_textile, :string, default: "", null: false
      remove :instructions_textile, :string, default: "", null: false
    end

    alter table(:forums) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:galleries) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:images) do
      remove :referrer, :string, default: ""
      remove :user_agent, :string, default: ""
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
      remove :tag_ids, {:array, :integer}, default: [], null: false
      remove :ne_intensity, :"double precision"
      remove :nw_intensity, :"double precision"
      remove :se_intensity, :"double precision"
      remove :sw_intensity, :"double precision"
      remove :average_intensity, :"double precision"
      remove :votes_count, :integer, default: 0, null: false
      remove :description_textile, :string, default: "", null: false
      remove :scratchpad_textile, :string
      remove :tag_list_cache, :string
      remove :tag_list_plus_alias_cache, :string
      remove :file_name_cache, :string
    end

    alter table(:messages) do
      remove :body_textile, :string, default: "", null: false
    end

    alter table(:mod_notes) do
      remove :body_textile, :text, default: "", null: false
    end

    alter table(:polls) do
      remove :hidden_from_users, :boolean, default: false, null: false
      remove :deleted_by_id, references(:users, name: "fk_rails_2bf9149369")
      remove :deletion_reason, :string, default: "", null: false
    end

    alter table(:posts) do
      remove :referrer, :string, default: ""
      remove :user_agent, :string, default: ""
      remove :name_at_post_time, :string
      remove :body_textile, :string, default: "", null: false
    end

    alter table(:reports) do
      remove :referrer, :string, default: ""
      remove :user_agent, :string, default: ""
      remove :reason_textile, :string, default: "", null: false
    end

    alter table(:roles) do
      remove :resource_id, :integer
      remove :created_at, :"timestamp without time zone"
      remove :updated_at, :"timestamp without time zone"
    end

    alter table(:source_changes) do
      remove :user_agent, :string, size: 255, default: ""
      remove :referrer, :string, size: 255, default: ""
    end

    alter table(:tags) do
      remove :description_textile, :string, default: ""
    end

    alter table(:tag_changes) do
      remove :user_agent, :string, default: ""
      remove :referrer, :string, default: ""
    end

    alter table(:topics) do
      remove :watcher_ids, {:array, :integer}, default: [], null: false
      remove :watcher_count, :integer, default: 0, null: false
    end

    alter table(:users) do
      remove :sign_in_count, :integer, default: 0, null: false
      remove :current_sign_in_at, :"timestamp without time zone"
      remove :current_sign_in_ip, :inet
      remove :last_sign_in_at, :"timestamp without time zone"
      remove :last_sign_in_ip, :inet
      remove :last_donation_at, :"timestamp without time zone"
      remove :unread_notification_ids, {:array, :integer}, default: [], null: false
      remove :description_textile, :string
      remove :scratchpad_textile, :text
    end
  end
end
