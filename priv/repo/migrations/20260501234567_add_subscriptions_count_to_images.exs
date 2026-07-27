defmodule Philomena.Repo.Migrations.AddSubscriptionsCountToImages do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add :subscriptions_count, :integer, default: 0, null: false
    end

    execute("""
    UPDATE images
    SET subscriptions_count = (
      SELECT COUNT(*) FROM image_subscriptions WHERE image_id = images.id
    )
    """)
  end
end
