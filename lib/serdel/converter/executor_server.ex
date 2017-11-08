defmodule Serdel.Converter.ExecutorServer do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init(_) do
    {:ok, %{results: %{}, tasks: %{}}}
  end

  def insert(server, input_ident, fun) do
    GenServer.call(server, {:insert, input_ident, fun})
  end

  def info(server, file_id) do
    GenServer.call(server, {:info, file_id})
  end

  def handle_call({:info, file_id}, _from, state) do
    ret =
    case Map.fetch(state.results, file_id) do
      :error ->
        %{status: :unknown, file: nil}
      {:ok, nil} ->
        %{status: :started, file: nil}
      {:ok, {:ok, file}} ->
        %{status: :finished, file: file}
    end
    {:reply, ret, state}
  end

  def handle_call({:insert, %Serdel.File{} = file, fun}, _from, state) do
    ident = :crypto.strong_rand_bytes(20) |> Base.url_encode64()
    Task.async(fn ->
      {:ready, ident, fun.(file, file, ident)}
    end)
    {:reply, {:ok, ident}, put_in(state, [:results, ident], nil)}
  end
  def handle_call({:insert, input_ident, fun}, _from, state) when is_bitstring(input_ident) do
    ident = :crypto.strong_rand_bytes(20) |> Base.url_encode64()

    case Map.fetch(state.results, input_ident) do
      {:ok, nil} ->
        new_task = {ident, fun}
        tasks = Map.update(state.tasks, input_ident, [new_task], &[new_task | &1])
        {:reply, {:ok, ident}, %{state | tasks: tasks}}

      {:ok, {:ok, result}} ->
        Task.async(fn ->
          {:ready, ident, fun.(result, result, ident)}
        end)

        {:reply, {:ok, ident}, put_in(state, [:results, input_ident], nil)}

      :error ->
        new_task = {ident, fun}
        tasks = Map.update(state.tasks, input_ident, [new_task], &[new_task | &1])
        {:reply, {:ok, ident}, %{state | tasks: tasks}}
    end
  end

  def handle_info({_, {:ready, ident, result}}, state) do
    new_state = put_in(state, [:results, ident], result)
    {:noreply, start_tasks(ident, result, new_state)}
  end
  def handle_info(res, state) do
    {:noreply, state}
  end

  defp start_tasks(root_ident, {:ok, result}, state) do
    case Map.fetch(state.tasks, root_ident) do
      {:ok, ts} ->
        Enum.each(ts, fn({ident, fun}) ->
          Task.async(fn -> {:ready, ident, fun.(result, elem(state.results[root_ident], 1), ident)} end)
        end)
        state
      :error ->
        state
    end

  end
end
