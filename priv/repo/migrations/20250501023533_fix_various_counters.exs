defmodule Philomena.Repo.Migrations.FixVariousCounters do
  use Ecto.Migration

  def change do
    alter table(:user_statistics) do
      add :topics, :integer, default: 0
    end

    rename table(:users), :topic_count, to: :topics_count

    execute "UPDATE users SET topics_count = (SELECT count(*) FROM topics WHERE user_id = users.id AND hidden_from_users IS FALSE)",
            "UPDATE users SET topics_count = 0"

    execute "UPDATE users SET forum_posts_count = (SELECT count(*) FROM posts WHERE user_id = users.id AND destroyed_content IS FALSE)",
            "UPDATE users SET forum_posts_count = (SELECT count(*) FROM posts WHERE user_id = users.id)"

    execute "UPDATE topics SET post_count = (SELECT count(*) FROM posts WHERE topic_id = topics.id AND destroyed_content IS FALSE)",
            "UPDATE topics SET post_count = (SELECT count(*) FROM posts WHERE topic_id = topics.id)"

    execute "UPDATE forums SET topic_count = (SELECT count(*) FROM topics WHERE forum_id = forums.id AND hidden_from_users IS FALSE)",
            "UPDATE forums SET topic_count = (SELECT count(*) FROM topics WHERE forum_id = forums.id)"

    execute "UPDATE forums SET post_count = (SELECT count(*) FROM posts JOIN topics ON posts.topic_id = topics.id WHERE topics.forum_id = forums.id AND topics.hidden_from_users IS FALSE AND posts.destroyed_content IS FALSE)",
            "UPDATE forums SET post_count = (SELECT count(*) FROM posts JOIN topics ON posts.topic_id = topics.id WHERE topics.forum_id = forums.id)"

    execute "UPDATE images SET comments_count = (SELECT count(*) FROM comments WHERE image_id = images.id AND destroyed_content IS FALSE)",
            "UPDATE images SET comments_count = (SELECT count(*) FROM comments WHERE image_id = images.id)"

    execute "UPDATE users SET comments_posted_count = (SELECT count(*) FROM comments WHERE user_id = users.id AND destroyed_content IS FALSE)",
            "UPDATE users SET comments_posted_count = (SELECT count(*) FROM comments WHERE user_id = users.id)"
  end
end
