defmodule Philomena.Repo.Migrations.CreateImageVectors do
  use Ecto.Migration

  def change do
    # NB: this is normalized, the float array is not divisible
    create table(:image_vectors) do
      add :image_id, references(:images, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :features, {:array, :float}, null: false
    end

    create unique_index(:image_vectors, [:image_id, :type])
  end
end
