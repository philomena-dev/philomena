defimpl Philomena.Attribution, for: Philomena.Versions.Difference do
  def object_identifier(difference) do
    Philomena.Attribution.object_identifier(difference.parent)
  end

  def best_user_identifier(difference) do
    Philomena.Attribution.best_user_identifier(difference.parent)
  end

  def anonymous?(difference) do
    same_user?(difference.user, difference.parent) and !!difference.parent.anonymous
  end

  defp same_user?(%{id: id}, %{user_id: id}), do: true
  defp same_user?(_user, _parent), do: false
end
