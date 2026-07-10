defmodule Philomena.ImagesTest do
  use Philomena.DataCase, async: true

  alias Philomena.Images

  import Philomena.ImagesFixtures
  import Philomena.UsersFixtures
  import Philomena.AttributionFixtures

  describe "create_image/2 duplicate detection" do
    # image_changeset's prepare_changes rejects a new upload whose
    # image_orig_sha512_hash already belongs to another image. On INSERT the
    # changeset's data.id is nil, so the self-exclusion added to fix the file
    # replacement bug never applies here - a genuine duplicate is still a
    # duplicate. create_image surfaces the changeset error as the raw Multi
    # failure tuple {:error, :image, changeset, changes}.
    test "rejects a new upload whose file duplicates an existing image's hash" do
      existing = image_fixture(image_orig_sha512_hash: png_upload_sha512())
      user = user_fixture()

      attrs = %{"image" => png_upload(), "tag_input" => "safe, solo, mare"}

      assert {:error, :image, changeset, _changes} =
               Images.create_image(attribution(user), attrs)

      assert "has already been uploaded: it's image #{existing.id}" in errors_on(changeset).image
    end
  end

  describe "update_file/2 duplicate detection" do
    # Root cause of the fixed bug: replacing an image's file with a
    # byte-identical copy. The image's own row still holds that file's
    # orig_sha512_hash, so the dedup lookup matches the image against itself;
    # the self-exclusion (other_image.id == changeset.data.id) lets it through
    # instead of raising a spurious "already been uploaded" error. The old code
    # sidestepped this by nulling the hash first; now no nulling is needed.
    test "allows replacing a file with a byte-identical copy of the image's own file" do
      sha = png_upload_sha512()
      image = image_fixture(image_sha512_hash: sha, image_orig_sha512_hash: sha)

      assert {:ok, updated} = Images.update_file(image, %{"image" => png_upload()})

      # The dedup fingerprint is still set - it is overwritten with the (same)
      # new file's hash, never nulled.
      assert updated.image_orig_sha512_hash == sha
    end

    # A file matching a *different* image is still rejected - the self-exclusion
    # only spares the image being updated, not genuine cross-image duplicates.
    # update_file returns the changeset error tuple unchanged.
    test "rejects replacing a file with one already uploaded as another image" do
      dup_sha = png_upload_sha512()
      other = image_fixture(image_sha512_hash: dup_sha, image_orig_sha512_hash: dup_sha)
      image = image_fixture()

      assert {:error, changeset} = Images.update_file(image, %{"image" => png_upload()})

      assert "has already been uploaded: it's image #{other.id}" in errors_on(changeset).image
      # The target image keeps its own fingerprint.
      assert Repo.reload!(image).image_orig_sha512_hash == image.image_orig_sha512_hash
    end
  end
end
