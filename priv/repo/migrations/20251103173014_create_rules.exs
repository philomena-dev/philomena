defmodule Philomena.Repo.Migrations.CreateRules do
  use Ecto.Migration

  def change do
    create table(:rules) do
      add :name, :string, null: false
      add :title, :string
      add :description, :string
      add :short_description, :string
      add :example, :string
      add :position, :integer, default: 999, null: false
      add :highlight, :boolean, default: false, null: false
      add :hidden, :boolean, default: false, null: false
      add :internal, :boolean, default: false, null: false

      timestamps()
    end

    create index(:rules, [:name], unique: true)
    create index(:rules, [:position], unique: true)

    create table(:rule_versions) do
      add :rule_id, references(:rules, on_delete: :delete_all), null: false

      add :name, :string, null: false
      add :title, :string
      add :description, :string
      add :short_description, :string
      add :example, :string

      timestamps()
    end

    execute("""
    INSERT INTO rules (name, title, description, short_description, example, position, highlight, hidden, internal, inserted_at, updated_at)
    VALUES ('Legacy', NULL, NULL, NULL, NULL, 999, false, true, true, NOW(), NOW());
    """)

    change table(:reports) do
      add :rule_id, references(:rules, on_delete: :restrict), default: 1
    end

    execute("ALTER TABLE reports ALTER COLUMN rule_id DROP DEFAULT;")
  end
end
