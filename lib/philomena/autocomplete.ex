defmodule Philomena.Autocomplete do
  @moduledoc """
  Pregenerated autocomplete files.

  These are used to eliminate the latency of looking up search results on the server.
  A script can parse the binary and generate results directly as the user types, without
  incurring any roundtrip penalty.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.Autocomplete.Autocomplete
  alias Philomena.Autocomplete.Generator
  alias Philomena.Autocomplete.Uploader

  @doc """
  Gets the current local autocompletion information.

  Returns nil if the binary is not currently generated.

  ## Examples

      iex> get_autocomplete()
      nil

      iex> get_autocomplete()
      %Autocomplete{}

  """
  def get_autocomplete do
    Autocomplete
    |> order_by(desc: :created_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Creates a new local autocompletion binary and prunes existing binaries.
  """
  def generate_and_prune_autocomplete! do
    generate_autocomplete!()
    prune_autocomplete!()
  end

  @doc """
  Creates a new local autocompletion binary.
  """
  def generate_autocomplete! do
    path = generate_autocomplete_file!()

    %Autocomplete{}
    |> Uploader.prepare_upload(path)
    |> Repo.insert!()
    |> Uploader.persist_upload()
  end

  @doc """
  Removes old autocomplete binaries.
  """
  def prune_autocomplete! do
    Autocomplete
    |> where([ac], ac.created_at < ago(1, "week"))
    |> Repo.all()
    |> Enum.each(&delete_autocomplete/1)
  end

  defp delete_autocomplete(%Autocomplete{} = autocomplete) do
    if autocomplete.file do
      Uploader.unpersist_upload(autocomplete)

      Autocomplete
      |> where([ac], ac.file == ^autocomplete.file)
      |> Repo.delete_all()
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp generate_autocomplete_file! do
    content = Generator.generate()
    file = Briefly.create!()

    File.write!(file, content)

    file
  end
end
