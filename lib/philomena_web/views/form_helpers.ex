defmodule PhilomenaWeb.FormHelpers do
  @moduledoc """
  Form controls in the markup of the framework's form components, which the plain
  `Phoenix.HTML.Form` helpers cannot emit.
  """

  use Phoenix.HTML

  @doc """
  A select with the framework's chevron. `full_width: true` stretches it over its column;
  the other options go to `Phoenix.HTML.Form.select/4`, a `:class` next to the field's own.
  """
  def select_field(form, field, options, opts \\ []) do
    {full_width, opts} = Keyword.pop(opts, :full_width, false)
    {class, opts} = Keyword.pop(opts, :class)
    width = if full_width, do: "full-width"

    content_tag(
      :span,
      [
        select(
          form,
          field,
          options,
          [class: ["input-field form-select-input", width, class]] ++ opts
        ),
        content_tag(:span, content_tag(:i, "", class: "fa fa-chevron-down"),
          class: "form-select-icon",
          aria_hidden: "true"
        )
      ],
      class: ["form-control-select", width]
    )
  end
end
