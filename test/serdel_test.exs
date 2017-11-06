defmodule SerdelTest do
  use ExUnit.Case, async: true
  doctest Serdel

  alias Serdel.Test.FileRepo

  @tmp_path "./tmp/"

  setup do
    files = Agent.start(fn -> [] end, name: TmpFileStore)

    on_exit(fn ->
      Agent.get(TmpFileStore, & &1)
      |> Enum.each(fn {path, pid} ->
           :ok = File.close(pid)
           :ok = File.rm(path)
         end)

      Agent.stop(TmpFileStore)
    end)

    {:ok, %{files: files}}
  end

  def new_temp_file(name, options \\ []) do
    path = @tmp_path <> name
    {:ok, pid} = File.open(path, options)
    :ok = Agent.update(TmpFileStore, &[{path, pid} | &1])
    {:ok, pid, path}
  end

  test "FileRepo.save/1 saves local file" do
    {:ok, _, path} = new_temp_file("newfile", [:write])
    File.write(path, "Some text")

    {:ok, file} =
      %Serdel.File{path: path}
      |> FileRepo.save()

    assert file.path != path
    assert File.read(path) == File.read(file.path)

    File.rm(file.path)
  end

  test "FileRepo.delete/1 deletes local files" do
    {:ok, _, path} = new_temp_file("newfile", [:write])
    File.write(path, "Some text")

    {:ok, file} =
      %Serdel.File{path: path}
      |> FileRepo.save()

    assert File.exists?(file.path)

    assert {:ok, file} = FileRepo.delete(file)
    refute File.exists?(file.path)
  end
end
