defmodule Philomena.Repo.Migrations.AddImageView do
  use Ecto.Migration

  def change do
	execute("""
	CREATE TABLE public.image_views (
		image_id bigint NOT NULL primary key references images(id), 
		views_count bigint NOT NULL DEFAULT 0
	);
	""")
  end
end
