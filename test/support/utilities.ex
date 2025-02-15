import ExUnit.Assertions

defmodule Philomena.TestUtilities do
  defp assert_retry(_, attempts, max_retries, _) when attempts > max_retries, do: false

  defp assert_retry(evalulation_lambda, attempts, max_retries, timeout_in_ms) do
    case evalulation_lambda.() do
      true ->
        true

      false ->
        Process.sleep(timeout_in_ms)
        assert_retry(evalulation_lambda, attempts + 1, max_retries, timeout_in_ms)
    end
  end

  def assert_retry(evaluation_lambda, max_retries \\ 3, timeout_in_ms \\ 1000)
      when is_function(evaluation_lambda) do
    assert assert_retry(evaluation_lambda, 0, max_retries, timeout_in_ms)
  end
end
