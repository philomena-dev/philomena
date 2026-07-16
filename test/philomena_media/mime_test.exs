defmodule PhilomenaMedia.MimeTest do
  use ExUnit.Case, async: true

  alias PhilomenaMedia.Mime

  @fixtures Path.expand("../support/fixtures/files", __DIR__)

  # Writes the given binary contents to a file inside the per-test tmp_dir and
  # returns the path. tmp_dir is unique per test, so this never touches shared
  # fixture paths.
  defp write_file(tmp_dir, name, contents) do
    path = Path.join(tmp_dir, name)
    File.write!(path, contents)
    path
  end

  describe "file/1 supported types" do
    @tag :tmp_dir
    test "detects PNG from a copied fixture without rewriting the input", %{tmp_dir: tmp_dir} do
      source = Path.join(@fixtures, "upload-test.png")
      original = File.read!(source)

      path = write_file(tmp_dir, "image.png", original)

      assert Mime.file(path) == {:ok, "image/png"}

      # The old RPC implementation rewrote inputs; the local sniffer must not.
      assert File.read!(path) == original
      # The shared fixture on disk must be untouched as well.
      assert File.read!(source) == original
    end

    @tag :tmp_dir
    test "detects SVG from the real fixture", %{tmp_dir: tmp_dir} do
      contents = File.read!(Path.join(@fixtures, "badge-test.svg"))
      path = write_file(tmp_dir, "badge.svg", contents)

      assert Mime.file(path) == {:ok, "image/svg+xml"}
    end

    @tag :tmp_dir
    test "detects JPEG from magic bytes", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "image.jpg", <<0xFF, 0xD8, 0xFF, 0xE0, "JFIF">>)

      assert Mime.file(path) == {:ok, "image/jpeg"}
    end

    @tag :tmp_dir
    test "detects GIF89a", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "image89.gif", "GIF89a" <> <<1, 0, 1, 0>>)

      assert Mime.file(path) == {:ok, "image/gif"}
    end

    @tag :tmp_dir
    test "detects GIF87a", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "image87.gif", "GIF87a" <> <<1, 0, 1, 0>>)

      assert Mime.file(path) == {:ok, "image/gif"}
    end

    @tag :tmp_dir
    test "detects WebM from an EBML DocType element", %{tmp_dir: tmp_dir} do
      contents =
        <<0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0x82, 0x84, "webm">>

      path = write_file(tmp_dir, "video.webm", contents)

      assert Mime.file(path) == {:ok, "video/webm"}
    end

    @tag :tmp_dir
    test "detects SVG with a UTF-8 BOM, XML declaration, and a comment before the root", %{
      tmp_dir: tmp_dir
    } do
      contents =
        <<0xEF, 0xBB, 0xBF>> <>
          ~s(<?xml version="1.0" encoding="UTF-8"?>\n) <>
          "<!-- a leading comment -->\n" <>
          ~s(<svg xmlns="http://www.w3.org/2000/svg"></svg>\n)

      path = write_file(tmp_dir, "prologue.svg", contents)

      assert Mime.file(path) == {:ok, "image/svg+xml"}
    end
  end

  describe "file/1 recognized-but-unsupported types" do
    @tag :tmp_dir
    test "reports Matroska as unsupported", %{tmp_dir: tmp_dir} do
      contents =
        <<0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0x82, 0x88, "matroska">>

      path = write_file(tmp_dir, "video.mkv", contents)

      assert Mime.file(path) == {:unsupported_mime, "video/x-matroska"}
    end

    @tag :tmp_dir
    test "reports XML without an <svg> element as text/plain", %{tmp_dir: tmp_dir} do
      contents = ~s(<?xml version="1.0"?>\n<root><child>text</child></root>\n)
      path = write_file(tmp_dir, "doc.xml", contents)

      assert Mime.file(path) == {:unsupported_mime, "text/plain"}
    end

    @tag :tmp_dir
    test "reports WebP as unsupported", %{tmp_dir: tmp_dir} do
      contents = "RIFF" <> <<100::little-32>> <> "WEBPVP8 "
      path = write_file(tmp_dir, "image.webp", contents)

      assert Mime.file(path) == {:unsupported_mime, "image/webp"}
    end

    @tag :tmp_dir
    test "reports MP4 as unsupported", %{tmp_dir: tmp_dir} do
      contents = <<0x00, 0x00, 0x00, 0x18, "ftypisom">>
      path = write_file(tmp_dir, "video.mp4", contents)

      assert Mime.file(path) == {:unsupported_mime, "video/mp4"}
    end

    @tag :tmp_dir
    test "reports PDF as unsupported", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "doc.pdf", "%PDF-1.4")

      assert Mime.file(path) == {:unsupported_mime, "application/pdf"}
    end

    @tag :tmp_dir
    test "reports ASCII plain text as unsupported", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "note.txt", "just some plain text\n")

      assert Mime.file(path) == {:unsupported_mime, "text/plain"}
    end

    @tag :tmp_dir
    test "reports multibyte UTF-8 plain text as unsupported", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "utf8.txt", "héllo wörld 日本語 🦄\n")

      assert Mime.file(path) == {:unsupported_mime, "text/plain"}
    end

    @tag :tmp_dir
    test "reports binary junk as octet-stream", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "junk.bin", <<0, 1, 2, 255, 254>>)

      assert Mime.file(path) == {:unsupported_mime, "application/octet-stream"}
    end

    @tag :tmp_dir
    test "reports an empty file as x-empty", %{tmp_dir: tmp_dir} do
      path = write_file(tmp_dir, "empty.bin", "")

      assert Mime.file(path) == {:unsupported_mime, "application/x-empty"}
    end
  end

  describe "file/1 unreadable paths" do
    @tag :tmp_dir
    test "returns :error for a nonexistent path", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "does-not-exist.bin")
      refute File.exists?(path)

      assert Mime.file(path) == :error
    end

    @tag :tmp_dir
    test "returns :error for a directory path", %{tmp_dir: tmp_dir} do
      assert Mime.file(tmp_dir) == :error
    end
  end

  describe "true_mime/1" do
    test "corrects image/svg to image/svg+xml" do
      assert Mime.true_mime("image/svg") == {:ok, "image/svg+xml"}
    end

    test "corrects audio/webm to video/webm" do
      assert Mime.true_mime("audio/webm") == {:ok, "video/webm"}
    end

    test "passes through supported MIME types unchanged" do
      for mime <- ~w(image/gif image/jpeg image/png image/svg+xml video/webm) do
        assert Mime.true_mime(mime) == {:ok, mime}
      end
    end

    test "wraps any other MIME type as unsupported" do
      assert Mime.true_mime("application/pdf") == {:unsupported_mime, "application/pdf"}
      assert Mime.true_mime("text/plain") == {:unsupported_mime, "text/plain"}
      assert Mime.true_mime("video/mp4") == {:unsupported_mime, "video/mp4"}
    end
  end
end
