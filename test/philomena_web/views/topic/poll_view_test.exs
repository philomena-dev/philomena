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

  test "ranks options by votes, ties in creation order, and names the first the winner once there are votes" do
    winners =
      &Enum.map(PollView.ranked_options(&1), fn {option, winner?} -> {option.id, winner?} end)

    assert winners.(poll([option(1, 2), option(2, 5), option(3, 2)])) == [
             {2, true},
             {1, false},
             {3, false}
           ]

    assert winners.(poll([option(1, 0), option(2, 0)])) == [{1, false}, {2, false}]
  end

  test "is active until its end and single choice by its vote method" do
    poll = poll([option(1, 0)])

    assert PollView.active?(poll)
    refute PollView.active?(%{poll | active_until: DateTime.add(DateTime.utc_now(), -1, :day)})
    assert PollView.single_choice?(poll)
    refute PollView.single_choice?(%{poll | vote_method: "multiple"})
  end

  test "shows each option's share of the votes as a progress bar named by the option" do
    results =
      &Phoenix.View.render_to_string(PollView, "_results.html", poll: poll(&1))

    html = results.([option(1, 1), option(2, 2)])

    assert html =~
             ~s(role="progressbar" aria-label="Option 1" aria-valuemin="0" aria-valuemax="100" aria-valuenow="33.33">)

    assert html =~ ~s(<svg class="progress-bar" width="33.33%">)
    assert html =~ "33.33% 1 vote"

    assert results.([option(1, 0)]) =~
             ~s(aria-label="Option 1" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">)
  end
end
