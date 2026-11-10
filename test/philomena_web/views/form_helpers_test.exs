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
end
