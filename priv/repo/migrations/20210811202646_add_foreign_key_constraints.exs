defmodule Philomena.Repo.Migrations.AddForeignKeyConstraints do
  use Ecto.Migration

  def change do
    execute("""
    ALTER TABLE image_views DROP CONSTRAINT image_views_image_id_fkey;
    """)
    execute("""
    ALTER TABLE ONLY image_views ADD CONSTRAINT public.image_views FOREIGN KEY (image_id) REFERENCES images(id) ON UPDATE CASCADE ON DELETE CAS>
    """)
  end
end