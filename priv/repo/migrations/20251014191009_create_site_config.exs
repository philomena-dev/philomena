defmodule Philomena.Repo.Migrations.CreateSiteConfig do
  use Ecto.Migration

  def change do
    create table(:configs) do
      add :key, :string, null: false
      add :value, :string, null: false
    end
  end
end
