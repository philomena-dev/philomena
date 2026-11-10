defmodule PhilomenaWeb.Topic.PollViewTest do
  use ExUnit.Case, async: true

  alias Philomena.PollOptions.PollOption
  alias Philomena.Polls.Poll
  alias PhilomenaWeb.Topic.PollView

  defp option(id, vote_count),
    do: %PollOption{id: id, label: "Option #{id}", vote_count: vote_count}

  defp poll(options) do
    %Poll{
      options: options,
      total_votes: Enum.sum_by(options, & &1.vote_count),
      vote_method: "single",
      active_until: DateTime.add(DateTime.utc_now(), 1, :day)
    }
  end

  test "ranks options by votes, ties in creation order, and names the first the winner" do
    poll = poll([option(1, 2), option(2, 5), option(3, 2)])

    assert Enum.map(PollView.ranked_options(poll), & &1.id) == [2, 1, 3]
    assert PollView.winning_option(poll).id == 2
  end

  test "is active until its end and single choice by its vote method" do
    poll = poll([option(1, 0)])

    assert PollView.active?(poll)
    refute PollView.active?(%{poll | active_until: DateTime.add(DateTime.utc_now(), -1, :day)})
    assert PollView.single_choice?(poll)
    refute PollView.single_choice?(%{poll | vote_method: "multiple"})
  end

  test "gives each option its share of the votes" do
    poll = poll([option(1, 1), option(2, 2)])

    assert to_string(PollView.percent_of_total(option(1, 1), poll)) == "33.33%"
    assert PollView.percent_of_total(option(1, 0), poll([option(1, 0)])) == "0%"
  end

  test "names the winning option only once there are votes" do
    poll = poll([option(1, 3), option(2, 1)])
    [winner, other] = poll.options

    assert PollView.winner?(winner, poll)
    refute PollView.winner?(other, poll)
    refute PollView.winner?(option(1, 0), poll([option(1, 0), option(2, 0)]))
  end
end
