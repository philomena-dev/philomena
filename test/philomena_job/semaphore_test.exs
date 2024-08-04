defmodule PhilomenaJob.SemaphoreTest do
  use ExUnit.Case, async: true

  alias PhilomenaJob.Semaphore.Server, as: SemaphoreServer

  @max_concurrency 8

  describe "Server functionality" do
    setup do
      {:ok, pid} = SemaphoreServer.start_link(max_concurrency: @max_concurrency)
      on_exit(fn -> Process.exit(pid, :kill) end)

      %{pid: pid}
    end

    test "allows max_concurrency processes to acquire", %{pid: pid} do
      # Check acquire
      results =
        (1..@max_concurrency)
        |> Task.async_stream(fn _ -> SemaphoreServer.acquire(pid) end)
        |> Enum.map(fn {:ok, res} -> res end)

      assert true == Enum.all?(results)

      # Check linking to process exit
      # If this hangs, linking to process exit does not release the semaphore
      results =
        (1..@max_concurrency)
        |> Task.async_stream(fn _ -> SemaphoreServer.acquire(pid) end)
        |> Enum.map(fn {:ok, res} -> res end)

      assert true == Enum.all?(results)
    end

    test "does not allow max_concurrency + 1 processes to acquire (exit)", %{pid: pid} do
      processes =
        (1..@max_concurrency)
        |> Enum.map(fn _ -> acquire_and_wait_for_release(pid) end)

      # This task should not be able to acquire
      task = Task.async(fn -> SemaphoreServer.acquire(pid) end)
      assert nil == Task.yield(task, 10)

      # Terminate processes holding the semaphore
      Enum.each(processes, &Process.exit(&1, :kill))

      # Now the task should be able to acquire
      assert {:ok, :ok} == Task.yield(task, 10)
    end

    test "does not allow max_concurrency + 1 processes to acquire (release)", %{pid: pid} do
      processes =
        (1..@max_concurrency)
        |> Enum.map(fn _ -> acquire_and_wait_for_release(pid) end)

      # This task should not be able to acquire
      task = Task.async(fn -> SemaphoreServer.acquire(pid) end)
      assert nil == Task.yield(task, 10)

      # Release processes holding the semaphore
      Enum.each(processes, &send(&1, :release))

      # Now the task should be able to acquire
      assert {:ok, :ok} == Task.yield(task, 10)
    end

    test "does not allow max_concurrency + 1 processes to acquire (run)", %{pid: pid} do
      processes =
        (1..@max_concurrency)
        |> Enum.map(fn _ -> run_and_wait_for_release(pid) end)

      # This task should not be able to acquire
      task = Task.async(fn -> SemaphoreServer.acquire(pid) end)
      assert nil == Task.yield(task, 10)

      # Release processes holding the semaphore
      Enum.each(processes, &send(&1, :release))

      # Now the task should be able to acquire
      assert {:ok, :ok} == Task.yield(task, 10)
    end

    test "does not allow re-acquire from the same process", %{pid: pid} do
      acquire = fn ->
        try do
          {:ok, SemaphoreServer.acquire(pid)}
        rescue
          err -> {:error, err}
        end
      end

      task = Task.async(fn ->
        acquire.()
        acquire.()
      end)

      assert {:ok, {:error, %MatchError{}}} = Task.yield(task)
    end

    test "allows re-release from the same process", %{pid: pid} do
      release = fn ->
        try do
          {:ok, SemaphoreServer.release(pid)}
        rescue
          err -> {:error, err}
        end
      end

      task = Task.async(fn ->
        release.()
        release.()
      end)

      assert {:ok, {:ok, :ok}} = Task.yield(task)
    end
  end

  defp run_and_wait_for_release(pid) do
    spawn(fn ->
      SemaphoreServer.run(pid, fn ->
        wait_for_release()
      end)
    end)
  end

  defp acquire_and_wait_for_release(pid) do
    spawn(fn ->
      SemaphoreServer.acquire(pid)
      wait_for_release()
      SemaphoreServer.release(pid)
    end)
  end

  defp wait_for_release do
    receive do
      :release ->
        :ok

      _ ->
        wait_for_release()
    end
  end
end
