defmodule Philomena.Repo.Migrations.ChangeDefaultFilter do
  use Ecto.Migration

  def change do
    execute("update filters set name = 'SFW Furry' where name = 'Default';")
  end
end
