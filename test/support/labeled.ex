defmodule Philomena.Labeled do
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
