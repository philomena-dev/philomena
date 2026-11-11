defmodule PhilomenaWeb.FormData do
  @moduledoc """
  The implementation of the forms `PhilomenaWeb.FormHelpers.form_for/4` builds: the one of the
  form's source, over params that hold only the submitted values an input can render. A map, an
  upload or a list holding anything but strings is dropped, so its input shows the form's data.
  The nested forms of a changeset take their params from the nested changesets instead.
  """

  alias Phoenix.HTML.FormData

  @doc """
  The form with this implementation and its params cut down to the values an input can render.
  """
  def renderable(form) do
    %{form | impl: __MODULE__, params: Map.filter(form.params, &renderable?/1)}
  end

  def to_form(source, form, field, opts) do
    source |> FormData.to_form(form, field, opts) |> Enum.map(&renderable/1)
  end

  defdelegate input_value(source, form, field), to: FormData
  defdelegate input_type(source, form, field), to: FormData
  defdelegate input_validations(source, form, field), to: FormData

  defp renderable?({_key, value}) when is_list(value), do: Enum.all?(value, &is_binary/1)
  defp renderable?({_key, value}), do: not is_map(value)
end
