defmodule Serdel.Converter.AgentStore do
  use Agent
  @behaviour Serdel.DataStore

  # TODO:
  # self() will change after restart, so this is not the best idea
  def start_link([]) do
    Agent.start_link(fn -> %{results: %{}} end, name: {:global, self()})
  end

  def info(file_promise) do
    Agent.get({:global, self()}, &do_info(&1, file_promise))
  end
  defp do_info(%{results: results}, file_promise) do
    case Map.fetch(results, file_promise) do
      :error ->
        {:ok, %{status: :not_registered, file: nil}}

      {:ok, %Serdel.File{} = file} ->
        {:ok, %{status: :finished, file: file}}

      {:ok, :started} ->
        {:ok, %{status: :started, file: nil}}

      {:ok, :registered} ->
        {:ok, %{status: :registered, file: nil}}
    end
  end

  def store(file_promise, file) do
    Agent.update({:global, self()}, &do_store(&1, file_promise, file))
  end

  defp do_store(state, file_promise, file) do
    put_in(state.results[file_promise], file)
  end

  def register_file() do
    {:ok, :crypto.strong_rand_bytes(20) |> Base.url_encode64()}
  end
end
