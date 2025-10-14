defmodule Philomena.Configs.Config do
  use Ecto.Schema
  import Ecto.Changeset

  schema "configs" do
    field :key, :string
    field :value, :string
  end

  @doc false
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:key, :value])
  end
end
