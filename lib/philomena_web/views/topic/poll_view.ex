defmodule PhilomenaWeb.Topic.PollView do
  use PhilomenaWeb, :view

  def ranked_options(poll) do
    poll.options
    |> Enum.sort_by(&{-&1.vote_count, &1.id})
  end

  def winning_option(poll) do
    poll
    |> ranked_options()
    |> Enum.at(0)
  end

  def active?(poll) do
    DateTime.diff(poll.active_until, DateTime.utc_now()) > 0
  end

  def single_choice?(%{vote_method: vote_method}), do: vote_method == "single"

  def percent_of_total(_option, %{total_votes: 0}), do: "0%"

  def percent_of_total(%{vote_count: vote_count}, %{total_votes: total_votes}) do
    :io_lib.format("~.2f%", [vote_count / total_votes * 100])
  end

  def winner?(_option, %{total_votes: 0}), do: false
  def winner?(%{id: id}, poll), do: winning_option(poll).id == id
end
