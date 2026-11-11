defmodule PhilomenaWeb.Admin.ArtistLinkViewTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.Admin.ArtistLinkView

  test "each state has its color, name and predicate" do
    for {state, class, name, predicate} <- [
          {"verified", "table-success", "Verified", :verified?},
          {"link_verified", "table-success", "Link verified", :link_verified?},
          {"unverified", "table-danger", "Unverified", :unverified?},
          {"rejected", "table-danger", "Rejected", :rejected?},
          {"contacted", "table-warning", "Contacted", :contacted?}
        ] do
      link = %{aasm_state: state}

      assert ArtistLinkView.link_state_class(link) == class
      assert ArtistLinkView.link_state_name(link) == name
      assert apply(ArtistLinkView, predicate, [link])
      refute apply(ArtistLinkView, predicate, [%{aasm_state: "other"}])
    end

    assert ArtistLinkView.link_state_class(%{aasm_state: "other"}) == nil
  end

  test "public state" do
    assert ArtistLinkView.public_text(%{public: true}) == "Yes"
    assert ArtistLinkView.public_text(%{public: false}) == "No"
    assert ArtistLinkView.public?(%{public: true})
    refute ArtistLinkView.public?(%{public: nil})
  end
end
