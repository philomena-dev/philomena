defmodule PhilomenaWeb.ErrorHelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML, only: [safe_to_string: 1]

  alias PhilomenaWeb.ErrorHelpers

  test "error_tag/2 renders each error of the field as a form error message" do
    form = %Phoenix.HTML.Form{
      errors: [
        source_url: {"is invalid", []},
        source_url: {"should be at most %{count} character(s)", [count: 255]}
      ]
    }

    assert form |> ErrorHelpers.error_tag(:source_url) |> Enum.map(&safe_to_string/1) == [
             ~s(<span class="form-message form-message-error">Source url is invalid</span>),
             ~s(<span class="form-message form-message-error">Source url should be at most 255 character(s\)</span>)
           ]

    assert ErrorHelpers.error_tag(form, :title) == []
  end
end
