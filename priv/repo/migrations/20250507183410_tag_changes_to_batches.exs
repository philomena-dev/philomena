defmodule Philomena.Repo.Migrations.TagChangesToBatches do
  use Ecto.Migration

  # Deliberately retain old tag_changes table,
  # in order to retain the ability to rollback easily.
  # TODO: remove in 2.0 release
  def up do
    rename table(:tag_changes), to: table(:tag_changes_legacy)

    create table(:tag_changes) do
      add :image_id, references(:images, on_update: :update_all, on_delete: :delete_all),
        null: false

      # if user is somehow gone, just null the column to turn this tag change into an anon tag change.
      add :user_id, references(:users, on_update: :update_all, on_delete: :nilify_all)
      add :ip, :inet, null: false
      add :fingerprint, :string, null: false
      timestamps(inserted_at: :created_at)
    end

    create table(:tag_change_tags, primary_key: false) do
      add :tag_change_id,
          references(:tag_changes, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :tag_id, references(:tags, on_update: :update_all, on_delete: :delete_all), null: false
      add :tag_name_cache, :string, default: "UNKNOWN TAG", null: false
      add :added, :boolean, null: false
    end

    create index(:tag_changes, [:user_id])
    create index(:tag_changes, [:image_id])
    create index(:tag_changes, ["ip inet_ops"], using: :gist)
    create index(:tag_changes, [:fingerprint])

    create index(:tag_change_tags, [:tag_change_id, :tag_id], unique: true)
    create index(:tag_change_tags, [:tag_id])
  end

  def down do
    drop table(:tag_change_tags)
    drop table(:tag_changes)
    rename table(:tag_changes_legacy), to: table(:tag_changes)
  end
end
