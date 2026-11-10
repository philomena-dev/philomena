defmodule PhilomenaWeb.SourceChangeViewTest do
  use ExUnit.Case, async: true

  alias Philomena.Images.Image
  alias Philomena.SourceChanges.SourceChange
  alias PhilomenaWeb.SourceChangeView

  @moderator %{role: "moderator", hide_default_role: false}

  defp change(user, anonymous_upload \\ false) do
    %SourceChange{user: user, user_id: 1, image: %Image{user_id: 1, anonymous: anonymous_upload}}
  end

  test "changes by staff showing their role mark the user cell" do
    assert SourceChangeView.user_column_class(change(@moderator)) == "table-success"

    for other <- [
          change(nil),
          change(@moderator, true),
          change(%{@moderator | role: "user"}),
          change(%{@moderator | hide_default_role: true})
        ] do
      assert SourceChangeView.user_column_class(other) == nil
    end
  end
end
