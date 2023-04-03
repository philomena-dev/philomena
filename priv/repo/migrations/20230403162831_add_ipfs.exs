defmodule Philomena.Repo.Migrations.AddIPFS do
  use Ecto.Migration

  def change do
    alter table("images") do
      add :ipfs, :varchar, default: nil
    end
  end
end
