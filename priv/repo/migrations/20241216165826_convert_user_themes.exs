defmodule Philomena.Repo.Migrations.ConvertUserThemes do
  use Ecto.Migration

  def up do
    execute("update users set theme = 'light-pink' where theme = 'default';")
    execute("update users set theme = 'dark-pink' where theme = 'dark';")
    execute("update users set theme = 'dark-red' where theme = 'red';")

    alter table("users") do
      modify :theme, :varchar, default: "dark-pink"
    end
  end

  def down do
    execute("update users set theme = 'default' where theme like 'light%';")
    execute("update users set theme = 'red' where theme = 'dark-red';")
    execute("update users set theme = 'dark' where theme like 'dark%';")

    alter table("users") do
      modify :theme, :varchar, default: "default"
    end
  end
end
