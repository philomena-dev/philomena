defmodule Philomena.Repo.Migrations.CreateAvatarShapes do
  use Ecto.Migration

  def change do
    create table(:avatar_parts) do
      add :name, :string, null: false
    end

    create table(:avatar_kind) do
      add :name, :string, null: false
    end

    create table(:avatar_shapes) do
      add :avatar_part_id,
          references(:avatar_parts, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :shape, :string, null: false
    end

    create table(:avatar_shape_kind) do
      add :avatar_shape_id,
          references(:avatar_shapes, on_update: :update_all, on_delete: :delete_all),
          null: false

      add :avatar_kind_id,
          references(:avatar_kind, on_update: :update_all, on_delete: :delete_all),
          null: false
    end
  end
end
