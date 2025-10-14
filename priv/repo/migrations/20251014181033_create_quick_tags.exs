defmodule Philomena.Repo.Migrations.CreateQuickTags do
  use Ecto.Migration

  def change do
    create table(:quick_tag_tabs) do
      add :title, :string, null: false
      add :position, :integer, null: false
    end

    create table(:default_quick_tags) do
      add :quick_tag_tab_id,
          references(:quick_tag_tabs, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :category, :string, null: false
      add :tags, {:array, :string}, null: false
    end

    create table(:shorthand_quick_tag_categories) do
      add :quick_tag_tab_id,
          references(:quick_tag_tabs, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :category, :string, null: false
    end

    create table(:shorthand_quick_tags) do
      add :shorthand_quick_tag_category_id,
          references(:shorthand_quick_tag_categories,
            on_update: :update_all,
            on_delete: :delete_all
          ),
          null: false

      add :shorthand, :string, null: false
      add :tag, :string, null: false
    end

    create table(:shipping_quick_tags) do
      add :quick_tag_tab_id,
          references(:quick_tag_tabs, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :category, :string, null: false
      add :implying, {:array, :string}, default: []
      add :not_implying, {:array, :string}, default: []
    end

    create table(:season_quick_tags) do
      add :quick_tag_tab_id,
          references(:quick_tag_tabs, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :episode, :integer, null: false
      add :tag, :string, null: false
    end
  end
end
