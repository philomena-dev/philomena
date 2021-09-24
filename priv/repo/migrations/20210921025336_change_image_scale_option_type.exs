defmodule Philomena.Repo.Migrations.ChangeImageScaleOptionType do
  use Ecto.Migration
  import Ecto.Query

  def change do
    alter table(:users) do
      add :scale_large_images0, :binary, default: "true", null: false
    end
  
    flush() # Not sure if this is necessary
  
    execute("update users set scale_large_images0 = (CASE WHEN scale_large_images THEN 'true'::bytea ELSE 'false'::bytea END) where scale_large_images is not null;")
  
    alter table(:users) do
      remove :scale_large_images
    end

    rename table(:users), :scale_large_images0, to: :scale_large_images
  end
end
