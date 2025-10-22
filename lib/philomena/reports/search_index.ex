defmodule Philomena.Reports.SearchIndex do
  @behaviour PhilomenaQuery.Search.Index

  @impl true
  def index_name do
    "reports"
  end

  @impl true
  def mapping do
    %{
      settings: %{
        index: %{
          number_of_shards: 5,
          max_result_window: 10_000_000
        }
      },
      mappings: %{
        dynamic: false,
        properties: %{
          id: %{type: "integer"},
          image_id: %{type: "keyword"},
          created_at: %{type: "date"},
          ip: %{type: "ip"},
          fingerprint: %{type: "keyword"},
          state: %{type: "keyword"},
          user: %{type: "keyword"},
          user_id: %{type: "keyword"},
          admin: %{type: "keyword"},
          admin_id: %{type: "keyword"},
          reportable_type: %{type: "keyword"},
          reportable_id: %{type: "keyword"},
          open: %{type: "boolean"},
          reason: %{type: "text", analyzer: "snowball"},
          system: %{type: "boolean"},
          related_user_ids: %{type: "keyword"},
          related_users: %{type: "keyword"}
        }
      }
    }
  end

  @impl true
  def as_json(report) do
    related_users = related_users(report) |> Enum.reject(&is_nil/1)

    %{
      id: report.id,
      image_id: image_id(report),
      created_at: report.created_at,
      ip: to_string(report.ip),
      state: report.state,
      user: if(report.user, do: String.downcase(report.user.name)),
      user_id: report.user_id,
      admin: if(report.admin, do: String.downcase(report.admin.name)),
      admin_id: report.admin_id,
      reportable_type: report.reportable_type,
      reportable_id: report.reportable_id,
      fingerprint: report.fingerprint,
      open: report.open,
      reason: report.reason,
      system: report.system,
      related_user_ids: related_users |> Enum.map(& &1.id),
      related_users: related_users |> Enum.map(&String.downcase(&1.name))
    }
  end

  def user_name_update_by_query(old_name, new_name) do
    old_name = String.downcase(old_name)
    new_name = String.downcase(new_name)

    %{
      query: %{
        bool: %{
          should: [
            %{term: %{user: old_name}},
            %{term: %{admin: old_name}},
            %{term: %{related_users: old_name}}
          ]
        }
      },
      replacements: [
        %{path: ["user"], old: old_name, new: new_name},
        %{path: ["admin"], old: old_name, new: new_name},
        %{path: ["related_users"], old: old_name, new: new_name}
      ],
      set_replacements: []
    }
  end

  defp image_id(%{reportable_type: "Image", reportable_id: image_id}), do: image_id
  defp image_id(%{reportable_type: "Comment", reportable: %{image_id: image_id}}), do: image_id
  defp image_id(_report), do: nil

  defp related_users(%{reportable_type: "User", reportable: user}), do: [user]

  defp related_users(%{reportable_type: "Image", reportable: %{user: user}}), do: [user]

  defp related_users(%{reportable_type: "Comment", reportable: %{user: user}}), do: [user]

  defp related_users(%{reportable_type: "Gallery", reportable: %{creator: creator}}),
    do: [creator]

  defp related_users(%{reportable_type: "Conversation", reportable: %{from: from, to: to}}),
    do: [from, to]

  defp related_users(%{reportable_type: "Post", reportable: %{user: user}}), do: [user]

  defp related_users(%{reportable_type: "Commission", reportable: %{user: user}}), do: [user]

  defp related_users(_report), do: []
end
