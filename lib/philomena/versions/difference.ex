defmodule Philomena.Versions.Difference do
  defstruct previous_version: nil,
            created_at: nil,
            parent: nil,
            user: nil,
            edit_reason: nil,
            difference: []
end
