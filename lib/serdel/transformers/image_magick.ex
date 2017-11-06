defmodule Serdel.Transformers.ImageMagick do
  def transform(%{input: %{path: input_path}, output: %{path: output_path}}, args) do
    convert_args = [input_path, args, output_path] |> List.flatten()
    System.cmd("convert", convert_args)
    :ok
  end
end
