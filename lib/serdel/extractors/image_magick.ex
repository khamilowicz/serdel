defmodule Serdel.Extractors.ImageMagick do
  defstruct [:height, :width]

  def info(%Serdel.File{} = file) do
    info = extract_info(file)
    {:ok, info}
  end

  defp extract_info(file) do
    case System.cmd("identify", [file.path]) do
      {output, 0} -> parse(output, file.path)
      other -> other
    end
  end

  defp parse(file_info, file_path) do
    String.trim_leading(file_info, file_path)
    |> String.trim()
    |> String.split(" ")
    |> do_parse
  end

  # ["JPEG", "2560x1440", "2560x1440+0+0", "8-bit", "sRGB", "628443B", "0.000u", "0:00.000"]
  defp do_parse([_type, size, _, _, _, _, _, _]) do
    [width, height] = String.split(size, "x") |> Enum.map(&String.to_integer/1)

    struct(__MODULE__, width: width, height: height)
  end
end
