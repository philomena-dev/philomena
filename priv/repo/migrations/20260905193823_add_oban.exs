defmodule Philomena.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up do
    Oban.Migration.up()
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
