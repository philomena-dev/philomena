defmodule Philomena.Repo.Migrations.UserStatisticsDayToDate do
  use Ecto.Migration

  def up do
    execute("alter table user_statistics alter column day drop default")

    execute(
      "alter table user_statistics alter column day type date using to_timestamp(day*86400)::date"
    )
  end

  def down do
    execute(
      "alter table user_statistics alter column day type integer using (extract(epoch from day)::integer/86400)"
    )

    execute("alter table user_statistics alter column day set default 0")
  end
end
