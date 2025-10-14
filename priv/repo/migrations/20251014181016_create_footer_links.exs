defmodule Philomena.Repo.Migrations.CreateFooterLinks do
  use Ecto.Migration

  def change do
    create table(:footer_categories) do
      add :title, :string, null: false
      add :position, :integer, null: false
    end

    create table(:footer_links) do
      add :footer_category_id,
          references(:footer_categories, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :title, :string, null: false
      add :url, :string, null: false
      add :position, :integer, null: false
      add :bold, :boolean, null: false, default: false
      add :new_tab, :boolean, null: false, default: false
    end
  end
end
