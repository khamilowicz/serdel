defmodule Serdel.ConverterTest do
  use ExUnit.Case, async: true

  alias Serdel.{Converter, Test.FileRepo, ImageInfo, Transformers}

  setup do
    resize_conversion =
      Converter.put_transformation(%Converter{}, Transformers.ImageMagick, ["-resize", "84x84\!"])

    another_resize_conversion =
      Converter.put_transformation(%Converter{}, Transformers.ImageMagick, ["-resize", "64x64\!"])

    resize_conversion =
      resize_conversion
      |> Converter.put_version(:resized, another_resize_conversion, fn file, meta ->
           Path.rootname(file.file_name) <> "_smaller" <> meta.extension
         end)
      |> Converter.put_repo(:resized, FileRepo)

    conversion_with_version =
      %Serdel.File{file_name: "test_image.jpg", path: "./test/support/test_image.jpg"}
      |> Converter.change(:original)
      |> Converter.put_transformation(Transformers.ImageMagick, ["-scale", "20x20\!"])
      |> Converter.put_version(:small, resize_conversion, fn file, meta ->
           Path.rootname(file.file_name) <> "_small" <> meta.extension
         end)
      |> Converter.put_repo(:original, FileRepo)
      |> Converter.put_repo(:small, FileRepo)

    on_exit fn ->
      File.ls!("./test/support/uploads/")
      |> Enum.map(&File.rm_rf("./test/support/uploads/#{&1}"))
    end

    {:ok, %{conversion: conversion_with_version}}
  end

  test "defines conversions of images", %{conversion: conversion} do
    assert %{
             original: {:ok, original_file},
             versions: %{
               small: {:ok, small_version},
               versions: %{resized: {:ok, smaller_version}}
             }
           } = Converter.execute(conversion)

    assert {:ok, info} = ImageInfo.extract(original_file)

    assert original_file.file_name == "test_image.jpg"
    assert info.height == 20
    assert info.width == 20

    assert {:ok, info} = ImageInfo.extract(small_version)

    assert small_version.file_name == "test_image_small.jpg"
    assert info.height == 84
    assert info.width == 84

    assert {:ok, info} = ImageInfo.extract(smaller_version)

    assert smaller_version.file_name == "test_image_small_smaller.jpg"
    assert info.height == 64
    assert info.width == 64
  end

  describe "Converter.async_execute" do
    test "executes conversions asynchronously", %{conversion: conversion} do
      assert %{
               original: {:ok, original_file_id},
               versions: %{
                 small: {:ok, small_version_id},
                 versions: %{resized: {:ok, smaller_version_id}}
               }
             } = Converter.async_execute(conversion)

      assert %{
               status: :started,
               file: nil
             } = Converter.info(original_file_id)

      Process.sleep(1_000)

      assert %{
               status: :finished,
               file: original_file
             } = Converter.info(original_file_id)

      assert %{
               status: :finished,
               file: small_version
             } = Converter.info(small_version_id)

      assert %{
               status: :finished,
               file: smaller_version
             } = Converter.info(smaller_version_id)


      assert {:ok, info} = ImageInfo.extract(original_file)

      assert original_file.file_name == "test_image.jpg"
      assert info.height == 20
      assert info.width == 20
    end

    test "executes conversions asynchronously and send messages to given process", %{
      conversion: conversion
    } do
      assert %{
        original: {:ok, {_, original_version_id}},
               versions: %{
                 small: {:ok, {_, small_version_id}},
                 versions: %{resized: {:ok, {_, smaller_version_id}}}
               }
             } = Converter.async_execute(conversion, stream: self())

      assert_receive {Serdel.Converter, ^original_version_id, :started}, 1_000
      assert_receive {Serdel.Converter, ^original_version_id, {:finished, original_file}}, 1_000
      assert_receive {Serdel.Converter, ^small_version_id, {:finished, small_version}}, 1_000
      assert_receive {Serdel.Converter, ^smaller_version_id, {:finished, smaller_version}}, 1_000
    end
  end

end
