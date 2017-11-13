defmodule Serdel.File do
  defstruct [:path, :file_name, meta: %{}]

  @type t :: __MODULE__

  def extract_meta(file) do
    extension = Path.extname(file.path)
    put_in(file.meta[:extension], extension)
  end
end
