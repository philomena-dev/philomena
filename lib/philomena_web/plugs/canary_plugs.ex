defmodule PhilomenaWeb.CanaryPlugs do
  @moduledoc """
  Drop-in wrappers around `Canary.Plugs` that reject an id which cannot name a
  row before Ecto tries to cast it.

  Canary loads resources with `Repo.get_by/2` on the raw path segment. When the
  id field is integer-typed, a segment like `not-a-number` raises
  `Ecto.Query.CastError` (a 400 under `phoenix_ecto`'s exception mappings) and
  one like `99999999999999999999` raises `DBConnection.EncodeError` (a 500),
  where the same route answers an unknown-but-valid id with the not-found
  handler.

  Such an id can never match, so these wrappers short-circuit to
  `PhilomenaWeb.NotFoundPlug` instead of querying. Controllers pick them up
  through `PhilomenaWeb.controller/0`; the plug names and options are Canary's.
  """

  alias PhilomenaWeb.IntegerId
  alias PhilomenaWeb.NotFoundPlug

  @doc "See `Canary.Plugs.load_resource/2`."
  def load_resource(conn, opts),
    do: guard_id(conn, opts, &Canary.Plugs.load_resource/2)

  @doc "See `Canary.Plugs.load_and_authorize_resource/2`."
  def load_and_authorize_resource(conn, opts),
    do: guard_id(conn, opts, &Canary.Plugs.load_and_authorize_resource/2)

  @doc "See `Canary.Plugs.authorize_resource/2`."
  def authorize_resource(conn, opts),
    do: guard_id(conn, opts, &Canary.Plugs.authorize_resource/2)

  @doc "See `Canary.Plugs.authorize_controller/2`."
  defdelegate authorize_controller(conn, opts), to: Canary.Plugs

  defp guard_id(conn, opts, canary_plug) do
    if unloadable_id?(conn, opts) do
      NotFoundPlug.call(conn)
    else
      canary_plug.(conn, opts)
    end
  end

  defp unloadable_id?(conn, opts) do
    action_valid?(conn, opts) and fetches_by_id?(conn, opts) and
      integer_id_field?(opts) and not castable_id?(resource_id(conn, opts))
  end

  # Mirrors the `cond` in Canary's `do_load_resource/2`: an id is only read from
  # the params when the resource is persisted or the action names one.
  defp fetches_by_id?(conn, opts),
    do: persisted?(opts) or action(conn) not in non_id_actions(opts)

  defp non_id_actions(opts),
    do: [:index, :new, :create] ++ List.wrap(opts[:non_id_actions])

  defp persisted?(opts),
    do: !!opts[:persisted] or !!opts[:required]

  defp integer_id_field?(opts) do
    field = String.to_existing_atom(opts[:id_field] || "id")

    opts[:model].__schema__(:type, field) in [:id, :integer]
  rescue
    ArgumentError -> false
  end

  # A missing id is Canary's business, not ours - it assigns nil and lets the
  # configured handler run.
  defp castable_id?(nil), do: true
  defp castable_id?(id), do: IntegerId.parse(id) != :error

  defp resource_id(conn, opts),
    do: conn.params[opts[:id_name] || "id"]

  defp action(conn),
    do: Map.get(conn.assigns, :canary_action, conn.private.phoenix_action)

  # Replicates Canary's `action_valid?/2` so `:only`/`:except` keep their meaning.
  defp action_valid?(conn, opts) do
    cond do
      Keyword.has_key?(opts, :except) and Keyword.has_key?(opts, :only) -> false
      Keyword.has_key?(opts, :except) -> not action_matches?(conn, opts[:except])
      Keyword.has_key?(opts, :only) -> action_matches?(conn, opts[:only])
      true -> true
    end
  end

  defp action_matches?(conn, actions) when is_list(actions), do: action(conn) in actions
  defp action_matches?(conn, action), do: action(conn) == action
end
