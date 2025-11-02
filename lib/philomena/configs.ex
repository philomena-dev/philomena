defmodule Philomena.Configs do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Philomena.Repo

  alias Philomena.Configs.Config

  def get(key) do
    key
    |> fetch()
    |> cast_value(Map.get(config_types(), key, :string))
  end

  def get_all() do
    defaults()
    |> Map.keys()
    |> Enum.map(fn key -> {key, get(key)} end)
    |> Map.new()
  end

  def set(key, value) do
    %Config{}
    |> Config.changeset(%{key: key, value: value})
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :key
    )
  end

  # Fetch config by its key.
  # This will try to fetch it from the environment variable first,
  # then from the database, and finally from the defaults.
  # If the environment variable is set, it will override the database value.
  # The environment variable must be set to the uppercase version of the key.
  defp fetch(key) do
    fetch(key, System.get_env(String.upcase(key), ""))
  end

  defp fetch(key, "") do
    case Repo.get_by(Config, key: key) do
      nil -> Map.get(defaults(), key)
      config -> config.value
    end
  end

  defp fetch(_, val) do
    val
  end

  defp cast_value(value, :integer), do: String.to_integer(value)
  defp cast_value(value, :boolean), do: value in ["true", "1", "yes"]
  defp cast_value(value, :float), do: String.to_float(value)
  defp cast_value(value, :list), do: String.split(value, ",") |> Enum.map(&String.trim/1)
  defp cast_value(value, _), do: value

  defp defaults do
    %{
      "site_name" => "Philomena",
      "site_slug" => "philomena",
      "site_description" => "The next-generation imageboard",
      "site_url" => "http://philomena.local",
      "default_theme" => "dark-blue",
      "default_light_theme" => "light-blue",
      "ad_text" => "Interested in advertising on {site_name}? Click here to learn more.",
      "donation_text" =>
        "This site is free to use, but costs money to run. If you enjoy using {site_name}, please consider supporting us financially.",
      "linkvalidation_format" => "PHILOMENA-LINKVALIDATION-{code}",
      "anonymous_name" => "Anonymous",
      "borderless_tags" => "false",
      "rounded_tags" => "false",
      "compact_hidden_communications" => "false",
      # todo
      "read_only_mode" => "false",
      "hide_version" => "false",
      "commissions_enabled" => "true",
      "livestreams_enabled" => "true",
      "dnp_enabled" => "true",
      "getting_started_enabled" => "false",
      "colored_logo" => "true",
      "allow_system_uploads" => "true",
      "default_filter_id" => "1",
      "everything_filter_id" => "2",
      "nsfw_filter_id" => "2",
      "minimum_tags" => "3",
      "hidden_trending_tags" => ""
    }
  end

  defp config_types do
    %{
      "site_name" => :string,
      "site_slug" => :string,
      "site_description" => :string,
      "site_url" => :string,
      "default_theme" => :string,
      "default_light_theme" => :string,
      "ad_text" => :string,
      "donation_text" => :string,
      "linkvalidation_format" => :string,
      "anonymous_name" => :string,
      "favicon_image" => :string,
      "tagblocked_image" => :string,
      "noavatar_image" => :string,
      "favicon_ico" => :string,
      "borderless_tags" => :boolean,
      "rounded_tags" => :boolean,
      "compact_hidden_communications" => :boolean,
      "read_only_mode" => :boolean,
      "hide_version" => :boolean,
      "commissions_enabled" => :boolean,
      "livestreams_enabled" => :boolean,
      "dnp_enabled" => :boolean,
      "getting_started_enabled" => :boolean,
      "colored_logo" => :boolean,
      "allow_system_uploads" => :boolean,
      "default_filter_id" => :integer,
      "everything_filter_id" => :integer,
      "nsfw_filter_id" => :integer,
      "minimum_tags" => :integer,
      "hidden_trending_tags" => :list
    }
  end
end
