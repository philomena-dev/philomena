defmodule Philomena.Repo.Migrations.ChangeImageScaleOptionType do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :scale_large_images, :binary, default: "true"
    end
  end
end
