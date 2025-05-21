defmodule Philomena.Labeled do
  # Defines a `label, value` pair. The callers can use the `label` to render
  # the value in a user-friendly way instead of using the `value` directly.
  # The `prefer*` methods can be used to extract the label/value out of the
  # value in case if it is a `Labeled` struct instance.
  @enforce_keys [:label, :value]
  defstruct [:label, :value]
  @type t(v) :: %__MODULE__{label: String.t(), value: v}

  @spec new(String.t(), a) :: t(a) when a: any()
  def new(label, value) do
    %__MODULE__{label: label, value: value}
  end

  def prefer_label(%__MODULE__{label: label}), do: label
  def prefer_label(unlabeled), do: unlabeled

  def prefer_value(%__MODULE__{value: value}), do: value
  def prefer_value(unlabeled), do: unlabeled
end
