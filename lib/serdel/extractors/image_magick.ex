defmodule Serdel.Extractors.ImageMagick do
  defstruct [:height, :width]

  def info(%Serdel.File{} = file) do
    {:ok, %__MODULE__{}}
  end
end
