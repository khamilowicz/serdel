defmodule Serdel.ConverterTest do
  use ExUnit.Case, async: true

  alias Serdel.{Converter, Test.FileRepo, ImageInfo, Transformers}

  test "defines conversions of images" do
    resize_conversion =
      Converter.put_transformation(%Converter{}, Transformers.ImageMagick, ["-resize", "64x64\!"])

    conversion_with_version =
      %Serdel.File{file_name: "test_image.jpg", path: "./test/support/test_image.jpg"}
      |> Converter.change(:original)
      |> Converter.put_transformation(Transformers.ImageMagick, ["-scale", "20x20\!"])
      |> Converter.put_version(:small, resize_conversion, fn file, meta ->
           Path.rootname(file.file_name) <> "_small" <> meta.extension
         end)
      |> Converter.put_repo(:original, FileRepo)
      |> Converter.put_repo(:small, FileRepo)

    assert {:ok, %{original: original_file, small: small_version}} =
             Converter.execute(conversion_with_version)

    assert {:ok, info} = ImageInfo.extract(original_file)

    assert info.height == 20
    assert info.width == 20

    assert {:ok, info} = ImageInfo.extract(small_version)

    assert info.height == 64
    assert info.width == 64
  end
end
