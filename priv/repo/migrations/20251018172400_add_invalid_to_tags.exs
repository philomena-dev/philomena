defmodule Philomena.Repo.Migrations.AddInvalidToTags do
  use Ecto.Migration

  def change do
    alter table("tags") do
      add :invalid, :boolean, default: false, null: false
    end
  end
end
