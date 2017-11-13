defmodule Serdel.Converter.ExecutorServer do
  use GenServer, restart: :transient

  @default_options %{
    data_store: Serdel.Converter.AgentStore,
  }

  def start_link(arg, opts \\ %{}) do
    GenServer.start_link(__MODULE__, {arg, opts})
  end

  def init({_arg, opts}) do
    options = Map.merge(@default_options, opts)
    # Supervisor.start_link([options[:data_store]], strategy: :one_for_one)
    options[:data_store].start_link([])
    {:ok, %{tasks: %{}, options: options}}
  end

  def insert(server, file_promise, fun) do
    GenServer.call(server, {:insert, file_promise, fun})
  end

  def info(server, file_promise) do
    GenServer.call(server, {:info, file_promise})
  end

  def handle_call({:info, file_promise}, _from, state) do
    file_info = get_result(state, file_promise)

    {:reply, file_info, state}
  end

  def handle_call({:insert, %Serdel.File{} = file, fun}, _from, state) do
    {:ok, file_promise} = generate_file_promise(state)
    start_work(file_promise, fun, file)
    {:reply, {:ok, file_promise}, insert_result(state, file_promise, :started)}
  end

  def handle_call({:insert, input_file_promise, fun}, _from, state)
  when is_bitstring(input_file_promise) do
    case get_result(state, input_file_promise) do
      {:ok, %{status: :finished, file: ready_file}} ->
        {:ok, file_promise} = generate_file_promise(state)
        start_work(file_promise, fun, ready_file)

        {:reply, {:ok, file_promise}, insert_result(state, file_promise, :started)}

      _ ->
        {:ok, file_promise} = generate_file_promise(state)

        new_state =
          insert_new_todo(state, input_file_promise, {file_promise, fun})
          |> insert_result(file_promise, :registered)

        {:reply, {:ok, file_promise}, new_state}
    end
  end

  def handle_info({_, {:ready, file_promise, {:ok, promised_file}}}, state) do
    new_state = insert_result(state, file_promise, promised_file)
    :ok = start_todos(file_promise, promised_file, new_state.tasks)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    if pending_tasks?(state) do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  defp pending_tasks?(_) do
    # Map.values(results)
    # |> Enum.any?(&is_nil/1)

    # TODO: remove when implemented file registry
    true
  end

  defp start_todos(ready_file_promise, promised_file, tasks) do
    tasks
    |> Map.get(ready_file_promise, [])
    |> Enum.each(fn {file_promise, fun} ->
         start_work(file_promise, fun, promised_file)
       end)
  end

  defp start_work(file_promise, fun, file) do
    Task.async(fn ->
      {:ready, file_promise, fun.(file, file_promise)}
    end)
  end

  defp generate_file_promise(%{options: %{data_store: data_store}}) do
    data_store.register_file()
  end

  defp insert_new_todo(state, file_promise, task) do
    tasks = Map.update(state.tasks, file_promise, [task], &[task | &1])
    %{state | tasks: tasks}
  end

  defp insert_result(%{options: %{data_store: data_store}} = state, file_promise, result) do
    data_store.store(file_promise, result)
    state
  end

  defp get_result(%{options: %{data_store: data_store}}, file_promise) do
    data_store.info(file_promise)
  end
end
