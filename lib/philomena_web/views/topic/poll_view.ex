defmodule PhilomenaWeb.Topic.PollView do
  use PhilomenaWeb, :view

  @doc """
  The options by votes, ties in creation order, each with whether it won: the first, once there are votes.
  """
  def ranked_options(poll) do
    ranked = Enum.sort_by(poll.options, &{-&1.vote_count, &1.id})
    winner = poll.total_votes > 0 && List.first(ranked)

    Enum.map(ranked, &{&1, &1 == winner})
  end

  def active?(poll) do
    DateTime.diff(poll.active_until, DateTime.utc_now()) > 0
  end

  def single_choice?(%{vote_method: vote_method}), do: vote_method == "single"

  @doc """
  The option's share of the votes in percent, to two decimals.
  """
  def percent_of_total(_option, %{total_votes: 0}), do: "0"

  def percent_of_total(%{vote_count: vote_count}, %{total_votes: total_votes}) do
    :io_lib.format("~.2f", [vote_count / total_votes * 100])
  end
end
