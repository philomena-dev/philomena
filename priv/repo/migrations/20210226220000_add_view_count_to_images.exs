defmodule Philomena.Repo.Migrations.AddDurationToImages do
  use Ecto.Migration

  def change do
    alter table("images") do
      add :views_count, :float
    end

    # After successful migration:
    #   alias Philomena.Elasticsearch
    #   alias Philomena.Images.Image
    #   Elasticsearch.update_mapping!(Image)
  end
end
