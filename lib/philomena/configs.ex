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
      "default_theme" => "dark-blue",
      "default_light_theme" => "light-blue",
      "ad_text" => "Interested in advertising on {site_name}? Click here to learn more.",
      "donation_text" => "This site is free to use, but costs money to run. If you enjoy using {site_name}, please consider supporting us financially.",
      "linkvalidation_format" => "PHILOMENA-LINKVALIDATION-{code}",
      "anonymous_name" => "Anonymous",
      "borderless_tags" => "false",
      "rounded_tags" => "false",
      "compact_hidden_communications" => "false",
      "read_only_mode" => "false", # todo
      "commissions_enabled" => "true",
      "livestreams_enabled" => "true",
      "dnp_enabled" => "true",
      "getting_started_enabled" => "false"
      "colored_logo" => "true",
      "default_filter_id" => "1",
      "everything_filter_id" => "2",
      "nsfw_filter_id" => "2"
    }
  end

  defp config_types do
    %{
      "site_name" => :envvar,
      "site_slug" => :envvar,
      "site_description" => :string,
      "default_theme" => :string,
      "default_light_theme" => :string,
      "ad_text" => :string,
      "donation_text" => :string,
      "linkvalidation_format" => :string,
      "anonymous_name" => :string,
      "borderless_tags" => :boolean,
      "rounded_tags" => :boolean,
      "compact_hidden_communications" => :boolean,
      "read_only_mode" => :boolean,
      "commissions_enabled" => :boolean,
      "livestreams_enabled" => :boolean,
      "dnp_enabled" => :boolean,
      "getting_started_enabled" => :boolean,
      "colored_logo" => :boolean,
      "default_filter_id" => :integer,
      "everything_filter_id" => :integer,
      "nsfw_filter_id" => :integer
    }
  end
end
