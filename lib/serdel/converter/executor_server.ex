defmodule Serdel.Converter.ExecutorServer do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init(_) do
    {:ok, %{results: %{}, tasks: %{}}}
  end

  def insert(server, file_promise, fun) do
    GenServer.call(server, {:insert, file_promise, fun})
  end

  def info(server, file_promise) do
    GenServer.call(server, {:info, file_promise})
  end

  def handle_call({:info, file_promise}, _from, state) do
    ret =
      case Map.fetch(state.results, file_promise) do
        :error ->
          %{status: :unknown, file: nil}
        {:ok, %Serdel.File{} = file} ->
          %{status: :finished, file: file}
        {:ok, nil} ->
          %{status: :started, file: nil}
      end
    {:reply, ret, state}
  end

  def handle_call({:insert, %Serdel.File{} = file, fun}, _from, state) do
    file_promise = start_work(generate_file_promise(), fun, file)
    {:reply, {:ok, file_promise}, insert_result(state, file_promise, nil)}
  end

  def handle_call({:insert, input_file_promise, fun}, _from, state) when is_bitstring(input_file_promise) do
    case Map.fetch(state.results, input_file_promise) do
      :error ->
        file_promise = generate_file_promise()
        {:reply, {:ok, file_promise}, insert_new_todo(state, input_file_promise, {file_promise, fun})}
      {:ok, nil} ->
        file_promise = generate_file_promise()
        {:reply, {:ok, file_promise}, insert_new_todo(state, input_file_promise, {file_promise, fun})}
      {:ok, %Serdel.File{} = ready_file} ->
        file_promise = start_work(generate_file_promise(), fun, ready_file)
        {:reply, {:ok, file_promise}, insert_result(state, file_promise, nil)}
    end
  end

  def handle_info({_, {:ready, file_promise, {:ok, promised_file}}}, state) do
    new_state = insert_result(state, file_promise, promised_file)
    start_todos(file_promise, promised_file, new_state.tasks)
    {:noreply, new_state}
  end
  def handle_info({:DOWN, _, _, _, _}, state) do
    {:noreply, state}
  end

  defp start_todos(ready_file_promise, promised_file, tasks) do
    tasks
    |> Map.get(ready_file_promise, [])
    |> Enum.each(fn({file_promise, fun}) ->
      start_work(file_promise, fun, promised_file)
    end)
  end

  defp start_work(file_promise, fun, file) do
    Task.async(fn ->
      {:ready, file_promise, fun.(file, file_promise)}
    end)
    file_promise
  end

  defp generate_file_promise() do
    :crypto.strong_rand_bytes(20) |> Base.url_encode64()
  end

  defp insert_new_todo(state, file_promise, task) do
    tasks = Map.update(state.tasks, file_promise, [task], &[task | &1])
    %{state | tasks: tasks}
  end

  defp insert_result(state, file_promise, result) do
    put_in state.results[file_promise], result
  end

end
