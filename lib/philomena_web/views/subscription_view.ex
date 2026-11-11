defmodule PhilomenaWeb.SubscriptionView do
  @moduledoc """
  The Subscribe and Unsubscribe links of a channel, forum, gallery or topic, which toggle the
  subscription of `target` in place, and the error shown when that fails.
  """

  use PhilomenaWeb, :view

  alias Philomena.Channels.Channel
  alias Philomena.Forums.Forum
  alias Philomena.Galleries.Gallery
  alias Philomena.Topics.Topic

  @doc "The subscription of a channel, forum or gallery, or of a topic given with its forum."
  def subscription_path(%Channel{} = channel), do: ~p"/channels/#{channel}/subscription"
  def subscription_path(%Forum{} = forum), do: ~p"/forums/#{forum}/subscription"
  def subscription_path(%Gallery{} = gallery), do: ~p"/galleries/#{gallery}/subscription"

  def subscription_path({%Forum{} = forum, %Topic{} = topic}),
    do: ~p"/forums/#{forum}/topics/#{topic}/subscription"
end
