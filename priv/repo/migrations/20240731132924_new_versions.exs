defmodule Philomena.Repo.Migrations.NewVersions do
  use Ecto.Migration

  def up do
    create table(:comment_versions) do
      add :comment_id, references(:comments, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps inserted_at: :created_at, updated_at: false

      add :body, :string, null: false
      add :edit_reason, :string
    end

    create table(:post_versions) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps inserted_at: :created_at, updated_at: false

      add :body, :string, null: false
      add :edit_reason, :string
    end

    create index(:comment_versions, [:comment_id, "created_at desc"])
    create index(:comment_versions, [:user_id])
    create index(:post_versions, [:post_id, "created_at desc"])
    create index(:post_versions, [:user_id])

    insert_statements =
      """
      insert into comment_versions (comment_id, user_id, created_at, body, edit_reason)
      select
        v.item_id as comment_id,
        v.whodunnit::bigint as user_id,
        v.created_at,
        v.object::json->>'body' as body,
        v.object::json->>'edit_reason' as edit_reason
      from versions v
      where v.item_type = 'Comment'
      and exists(select 1 from comments c where c.id = v.item_id)
      and v.whodunnit is not null
      and v.event = 'update'
      order by created_at asc;

      insert into post_versions (post_id, user_id, created_at, body, edit_reason)
      select
        v.item_id as post_id,
        v.whodunnit::bigint as user_id,
        v.created_at,
        v.object::json->>'body' as body,
        v.object::json->>'edit_reason' as edit_reason
      from versions v
      where v.item_type = 'Post'
      and exists(select 1 from posts p where p.id = v.item_id)
      and v.whodunnit is not null
      and v.event = 'update'
      order by created_at asc;
      """

    # These statements should not be run by the migration in production.
    # Run them manually in psql instead.
    if System.get_env("MIX_ENV") != "prod" do
      for stmt <- String.split(insert_statements, "\n\n") do
        execute(stmt)
      end
    end
  end

  def down do
    drop table(:comment_versions)
    drop table(:post_versions)
  end
end
