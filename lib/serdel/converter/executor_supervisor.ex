defmodule Serdel.Converter.ExecutorSupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_) do
    Supervisor.init([
      Serdel.Converter.ExecutorServer
    ], strategy: :simple_one_for_one)
  end

end
