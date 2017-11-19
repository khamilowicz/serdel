defmodule Serdel.Converter.MemoryStore do
  @behaviour Serdel.DataStore

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  # TODO:
  # self() will change after restart, so this is not the best idea
  def start_link() do
    Agent.start_link(fn -> :ets.new(__MODULE__, [:set, :public, :named_table]) end)
  end

  def info(file_promise) do
    case :ets.lookup(__MODULE__, file_promise) do
      [{^file_promise, :started}] ->
        {:ok, %{status: :started, file: nil}}
      [{^file_promise, :registered}] ->
        {:ok, %{status: :registered, file: nil}}
      [{^file_promise, %Serdel.File{} = file}] ->
        {:ok, %{status: :finished, file: file}}
      [] ->
        {:ok, %{status: :not_registered, file: nil}}
    end
  end

  def store(file_promise, file) do
    :ets.insert(__MODULE__, {file_promise, file})
  end

  def register_file() do
    {:ok, :crypto.strong_rand_bytes(20) |> Base.url_encode64()}
  end
end
