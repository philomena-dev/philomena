defmodule PhilomenaWeb.FormHelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML, only: [safe_to_string: 1]

  alias PhilomenaWeb.FormHelpers

  defp form(params \\ %{}), do: Phoenix.HTML.FormData.to_form(params, as: :user)

  describe "select_field/4" do
    test "wraps the select with the chevron and keeps the given options" do
      html =
        form(%{"sd" => "asc"})
        |> FormHelpers.select_field(:sd, [Descending: "desc", Ascending: "asc"],
          class: "me-md",
          autocomplete: "off"
        )
        |> safe_to_string()

      assert html =~
               ~s(<span class="form-control-select"><select autocomplete="off" class="input-field form-select-input me-md" id="user_sd" name="user[sd]">)

      assert html =~ ~s(<option selected value="asc">Ascending</option>)

      assert html =~
               ~s(<span aria-hidden="true" class="form-select-icon"><i class="fa fa-chevron-down"></i></span></span>)
    end

    test "stretches the wrapper and the select over the column with full_width" do
      html = form() |> FormHelpers.select_field(:sd, ["a"], full_width: true) |> safe_to_string()

      assert html =~ ~s(<span class="form-control-select full-width">)
      assert html =~ ~s(class="input-field form-select-input full-width")
      refute html =~ "full_width"
    end
  end

  describe "checkbox_field/4" do
    test "draws the box in a row of its own with its label after it" do
      html =
        form(%{"anonymous" => "true"})
        |> FormHelpers.checkbox_field(:anonymous, "Post anonymously",
          class: "js-preview-anonymous"
        )
        |> safe_to_string()

      assert html =~
               ~s(<div class="form-control-wrap"><div class="form-control-checkbox"><span class="form-checkbox-input-wrap">)

      assert html =~
               ~s(<input checked class="form-checkbox-input js-preview-anonymous" id="user_anonymous" name="user[anonymous]" type="checkbox" value="true">)

      assert html =~
               ~s(<i aria-hidden="true" class="form-checkbox-check-icon fa fa-check"></i></span><label class="form-checkbox-label" for="user_anonymous">Post anonymously</label></div></div>)
    end

    test "points the label at a given id" do
      html =
        :tag_change
        |> FormHelpers.checkbox_field(:revert, "Revert", id: "revert_5", hidden_input: false)
        |> safe_to_string()

      assert html =~ ~s(id="revert_5")
      assert html =~ ~s(<label class="form-checkbox-label" for="revert_5">)
    end

    test "points the label at a box with a checked value" do
      html =
        :commission
        |> FormHelpers.checkbox_field(:Anthro, "Anthro",
          checked_value: "Anthro",
          hidden_input: false
        )
        |> safe_to_string()

      assert html =~
               ~s(id="commission_Anthro" name="commission[Anthro]" type="checkbox" value="Anthro")

      assert html =~ ~s(<label class="form-checkbox-label" for="commission_Anthro">)
    end
  end

  describe "collection_checkboxes/4" do
    test "checks the selected values and submits an empty list when none is checked" do
      html =
        form()
        |> FormHelpers.collection_checkboxes(:roles, [{"Manage images", 1}, {"Alias tags", 2}],
          selected: [2]
        )
        |> Phoenix.HTML.html_escape()
        |> safe_to_string()

      assert html =~
               ~s(<input class="form-checkbox-input" id="user_roles_1" name="user[roles][]" type="checkbox" value="1">)

      assert html =~
               ~s(<input checked class="form-checkbox-input" id="user_roles_2" name="user[roles][]" type="checkbox" value="2">)

      assert html =~ ~s(<label class="form-checkbox-label" for="user_roles_2">Alias tags</label>)
      assert html =~ ~s(<input id="user_roles" name="user[roles][]" type="hidden" value="">)
    end
  end

  describe "error_summary/1" do
    test "is empty until the changeset was submitted" do
      assert FormHelpers.error_summary(%Ecto.Changeset{action: nil}) == nil

      html = %Ecto.Changeset{action: :insert} |> FormHelpers.error_summary() |> safe_to_string()

      assert html ==
               ~s(<div class="alert alert-danger"><p>Oops, something went wrong! Please check the errors below.</p></div>)
    end
  end
end
