defmodule Serdel.TempFile do
  @tmp_dir "./tmp/"

  def new do
    file_name = "random"
    file_path = Path.join(@tmp_dir, file_name)
    {:ok, pid} = File.open(file_path, [:read, :write])
    {:ok, %Serdel.File{path: file_path, file_name: file_name}}
  end
end
