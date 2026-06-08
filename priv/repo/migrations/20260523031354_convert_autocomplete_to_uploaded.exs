defmodule Philomena.Repo.Migrations.ConvertAutocompleteToUploaded do
  use Ecto.Migration

  def change do
    alter table(:autocomplete) do
      remove :content, :binary
      add :file, :string
    end
  end
end
