defmodule PhilomenaMedia.Mime do
  @moduledoc """
  Utilities for determining the MIME type of a file via parsing.

  Many MIME type libraries assume the MIME type of the file by reading file extensions.
  This is inherently unreliable, as many websites disguise the content types of files with
  specific names for cost or bandwidth saving reasons. As processing depends on correctly
  identifying the type of a file, parsing the file contents is necessary.

  Detection reads only the first bytes of the file locally; the file is never
  modified or forwarded to the media processor.
  """

  @type t :: String.t()

  # Bytes of file content to read for detection. Every supported format is
  # identifiable from its opening bytes; the allowance beyond that is for
  # SVG documents with long prologues.
  @head_size 4096

  @doc """
  Gets the MIME type of the given pathname.

  ## Examples

      iex> PhilomenaMedia.Mime.file("image.png")
      {:ok, "image/png"}

      iex> PhilomenaMedia.Mime.file("file.txt")
      {:unsupported_mime, "text/plain"}

      iex> PhilomenaMedia.Mime.file("nonexistent.file")
      :error

  """
  @spec file(Path.t()) :: {:ok, t()} | {:unsupported_mime, t()} | :error
  def file(path) do
    case read_head(path) do
      {:ok, head} ->
        true_mime(sniff(head))

      :error ->
        :error
    end
  end

  @doc """
  Provides the "true" MIME type of this file.

  Some files are identified as a type they should not be based on how they are used by
  this library. These MIME types (and their "corrected") versions are:

  - `image/svg` -> `image/svg+xml`
  - `audio/webm` -> `video/webm`

  ## Examples

    iex> PhilomenaMedia.Mime.true_mime("image/svg")
    {:ok, "image/svg+xml"}

    iex> PhilomenaMedia.Mime.true_mime("audio/webm")
    {:ok, "video/webm"}

  """
  @spec true_mime(String.t()) :: {:ok, t()} | {:unsupported_mime, t()}
  def true_mime("image/svg"), do: {:ok, "image/svg+xml"}
  def true_mime("audio/webm"), do: {:ok, "video/webm"}

  def true_mime(mime)
      when mime in ~W(image/gif image/jpeg image/png image/svg+xml video/webm),
      do: {:ok, mime}

  def true_mime(mime), do: {:unsupported_mime, mime}

  # sobelow_skip ["Traversal.FileModule"]
  @spec read_head(Path.t()) :: {:ok, binary()} | :error
  defp read_head(path) do
    case File.open(path, [:read, :raw, :binary]) do
      {:ok, device} ->
        data = :file.read(device, @head_size)
        File.close(device)

        case data do
          {:ok, head} -> {:ok, head}
          :eof -> {:ok, <<>>}
          _error -> :error
        end

      _error ->
        :error
    end
  end

  @spec sniff(binary()) :: t()
  defp sniff(<<>>), do: "application/x-empty"
  defp sniff(<<0x89, "PNG\r\n", 0x1A, "\n", _::binary>>), do: "image/png"
  defp sniff(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp sniff(<<"GIF87a", _::binary>>), do: "image/gif"
  defp sniff(<<"GIF89a", _::binary>>), do: "image/gif"
  defp sniff(<<0x1A, 0x45, 0xDF, 0xA3, _::binary>> = head), do: ebml_mime(head)
  defp sniff(<<"RIFF", _size::32, "WEBP", _::binary>>), do: "image/webp"
  defp sniff(<<_size::32, "ftyp", _::binary>>), do: "video/mp4"
  defp sniff(<<"%PDF", _::binary>>), do: "application/pdf"
  defp sniff(head), do: sniff_text(head)

  # An EBML container is WebM or Matroska depending on its DocType element
  # (id 0x4282), whose value appears in the first bytes of the file.
  @spec ebml_mime(binary()) :: t()
  defp ebml_mime(head) do
    cond do
      :binary.match(head, <<0x42, 0x82, 0x84, "webm">>) != :nomatch ->
        "video/webm"

      :binary.match(head, <<0x42, 0x82, 0x88, "matroska">>) != :nomatch ->
        "video/x-matroska"

      true ->
        "application/octet-stream"
    end
  end

  @spec sniff_text(binary()) :: t()
  defp sniff_text(head) do
    cond do
      svg?(head) -> "image/svg+xml"
      text?(head) -> "text/plain"
      true -> "application/octet-stream"
    end
  end

  # A document is treated as SVG when it opens like an XML document and an
  # <svg> element appears within the head bytes.
  @spec svg?(binary()) :: boolean()
  defp svg?(head) do
    markup?(head) and :binary.match(head, ["<svg", "<SVG"]) != :nomatch
  end

  @spec markup?(binary()) :: boolean()
  defp markup?(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: markup?(rest)
  defp markup?(<<c, rest::binary>>) when c in ~c[ \t\r\n], do: markup?(rest)
  defp markup?(<<"<", _::binary>>), do: true
  defp markup?(_head), do: false

  # A full head buffer may end mid-way through a UTF-8 codepoint, so also
  # accept text that becomes valid after dropping up to three trailing bytes.
  @spec text?(binary()) :: boolean()
  defp text?(head) do
    max_trim = if byte_size(head) == @head_size, do: min(3, byte_size(head)), else: 0

    Enum.any?(0..max_trim, fn trim ->
      String.valid?(binary_part(head, 0, byte_size(head) - trim))
    end)
  end
end
