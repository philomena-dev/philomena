defmodule Philomena.Autocomplete.Uploader do
  @moduledoc """
  Upload callback logic for Autocomplete.
  """

  alias Philomena.Autocomplete.Autocomplete
  alias PhilomenaMedia.Filename
  alias PhilomenaMedia.Uploader

  @field_name "file"

  def prepare_upload(autocomplete, path) do
    storage_key = Filename.build("bin")

    Uploader.prepare_upload(
      autocomplete,
      @field_name,
      storage_key,
      path,
      &Autocomplete.changeset/2
    )
  end

  def persist_upload(autocomplete) do
    Uploader.persist_upload(autocomplete, autocomplete_file_root(), @field_name)
  end

  def unpersist_upload(autocomplete) do
    autocomplete
    |> Map.put(:removed_file, autocomplete.file)
    |> Uploader.unpersist_old_upload(autocomplete_file_root(), @field_name)
  end

  defp autocomplete_file_root do
    Application.get_env(:philomena, :autocomplete_file_root)
  end
end
