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

  @doc """
  A checkbox drawn by the framework, with its label after it, in a row of its own. The options go to
  `Phoenix.HTML.Form.checkbox/3`, a `:class` next to the box's own; an `:id` is the label's target.
  """
  def checkbox_field(form, field, label_text, opts \\ []) do
    {class, opts} = Keyword.pop(opts, :class)
    opts = Keyword.put_new_lazy(opts, :id, fn -> input_id(form, field) end)
    id = opts[:id]

    box =
      content_tag(
        :span,
        [
          checkbox(form, field, [class: ["form-checkbox-input", class]] ++ opts),
          content_tag(:i, "", class: "form-checkbox-check-icon fa fa-check", aria_hidden: "true")
        ],
        class: "form-checkbox-input-wrap"
      )

    control =
      content_tag(
        :div,
        [box, label(form, field, label_text, for: id, class: "form-checkbox-label")],
        class: "form-control-checkbox"
      )

    content_tag(:div, control, class: "form-control-wrap")
  end

  @doc """
  One `checkbox_field/4` per `{label, value}` of the collection for a list field, the values in
  `:selected` checked, and an empty value that submits the list when nothing is checked.
  """
  def collection_checkboxes(form, field, collection, opts \\ []) do
    name = input_name(form, field) <> "[]"
    selected = Keyword.get(opts, :selected, [])

    boxes =
      Enum.map(collection, fn {label_text, value} ->
        checkbox_field(form, field, label_text,
          id: "#{input_id(form, field)}_#{value}",
          name: name,
          checked_value: value,
          checked: value in selected,
          hidden_input: false
        )
      end)

    [boxes, hidden_input(form, field, name: name, value: "")]
  end

  @doc """
  The alert at the top of a form whose changeset failed to save, nothing otherwise.
  """
  def error_summary(%{action: nil}), do: nil

  def error_summary(_changeset) do
    content_tag(
      :div,
      content_tag(:p, "Oops, something went wrong! Please check the errors below."),
      class: "alert alert-danger"
    )
  end
end
