defmodule Philomena.Repo.Migrations.CreateSiteConfig do
  use Ecto.Migration

  def change do
    create table(:configs) do
      add :key, :string, null: false
      add :value, :string, null: false
    end

    create table(:system_images) do
      add :key, :string, null: false
    end

    create index(:configs, [:key], unique: true)
    create index(:system_images, [:key], unique: true)
  end
end
