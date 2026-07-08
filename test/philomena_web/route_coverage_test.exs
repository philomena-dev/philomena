defmodule PhilomenaWeb.RouteCoverageTest do
  use ExUnit.Case, async: true

  alias PhilomenaWeb.RouteCoverage

  test "test/route_coverage.txt is in sync with the router" do
    assert File.read!(RouteCoverage.file_path()) == RouteCoverage.rendered(),
           """
           test/route_coverage.txt does not match the router, so a route was
           added, removed, or changed without updating the coverage checklist.

           Regenerate the file (checked marks are preserved) with:

             docker compose exec -T -e MIX_ENV=test app \\
               mix run --no-start -e 'PhilomenaWeb.RouteCoverage.regenerate()'
           """
  end
end
