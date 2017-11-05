defmodule Serdel.Repo.Local do
  @behaviour Serdel.Repo

  @moduledoc """
  Local storage for files.
  """

  alias Serdel.File, as: SerFile

  defmacro __using__(opts) do
    storage_dir =
      Keyword.get(opts, :storage_dir) ||
        raise """
        Option `storage_dir` is required for `#{__MODULE__}`.
        """

    unless File.dir?(storage_dir) do
      raise """
      Path `#{storage_dir}` should exist.
      """
    end

    quote location: :keep do
      @storage_dir unquote(opts[:storage_dir])

      def storage_path(%{path: path}) do
        @storage_dir <> "/" <> Path.basename(path)
      end

      def delete(%SerFile{path: path} = file) when is_bitstring(path) do
        with :ok <- File.rm(path) do
          {:ok, file}
        end
      end

      def save(%SerFile{path: path} = file) when is_bitstring(path) do
        with {:exists, true} <- {:exists, File.exists?(path)},
             new_path = storage_path(file),
             :ok <- File.cp(path, new_path) do
          {:ok, %SerFile{path: new_path}}
        else
          {:exists, false} ->
            {:error, :enoent}

          {:error, :enoent} ->
            {:error, :enoent}
        end
      end
    end
  end
end
