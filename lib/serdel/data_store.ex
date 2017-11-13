defmodule Serdel.DataStore do

  @type file_ref :: any
  @type file_info :: {:ok, %{status: term, file: Serdel.File.t}} | {:error, %{status: :unknown, file: nil}}

  @callback store(file_ref, Serdel.File.t | nil) :: {:ok, file_ref} | {:error, any}
  @callback info(file_ref) :: file_info
  @callback register_file :: file_ref
  @callback start_link :: {:ok, any} | {:error, any}

end
