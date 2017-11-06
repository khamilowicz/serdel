defmodule Serdel.Converter do
  defstruct versions: %{}, root: nil, transformation: nil, repo: nil, file: nil

  defmodule Version do
    defstruct [:conversion, :name_fun]
  end

  def change(converter_or_file, name \\ nil)

  def change(%__MODULE__{} = converter, _name) do
    converter
  end

  def change(file, name) do
    %__MODULE__{root: name, file: file}
  end

  def put_transformation(conversion, transformer, args) do
    %{conversion | transformation: {transformer, args}}
  end

  def put_version(conversion, name, conv, name_fun) do
    update_in(
      conversion.versions,
      &Map.put(&1, name, %Version{conversion: %{conv | root: name}, name_fun: name_fun})
    )
  end

  def put_repo(%{root: name} = conversion, name, repo) do
    %{conversion | repo: repo}
  end

  def put_repo(%{versions: versions} = conversion, name, repo) do
    version = Map.get(versions, name)
    new_version = put_in(version.conversion.repo, repo)
    update_in(conversion.versions, &Map.put(&1, name, new_version))
  end

  def execute(root_conversion) do
    list_versions(root_conversion)
    |> Enum.map(fn {name, conversion} ->
         {name, execute_conversion(root_conversion.file, conversion)}
       end)
    |> Enum.reduce({:ok, %{}}, fn
         {_, _}, {:error, sum} -> {:error, sum}
         {name, {:ok, val}}, {:ok, sum} -> {:ok, Map.put(sum, name, val)}
         {name, {:error, val}}, sum -> {:error, val}
       end)
  end

  defp execute_conversion(input_file, %{repo: repo, file: file, transformation: nil}) do
    repo.save(%{input_file | file_name: file.file_name})
  end

  defp execute_conversion(input_file, %{
         repo: repo,
         file: file,
         transformation: {transformer, args}
       }) do
    {:ok, temp_file} = Serdel.TempFile.new()
    :ok = transformer.transform(%{input: input_file, output: temp_file}, args)
    repo.save(%{temp_file | file_name: file.file_name})
  end

  defp list_versions(root_conversion) do
    root_conversion.versions
    |> Enum.map(fn {key, %{conversion: conversion, name_fun: name_fun}} ->
         {key, set_file_name(conversion, root_conversion, name_fun)}
       end)
    |> Enum.into(%{root_conversion.root => root_conversion})
  end

  defp set_file_name(conversion, %{file: file}, name_fun) do
    extension = Path.extname(file.file_name)
    %{conversion | file: %Serdel.File{file_name: name_fun.(file, %{extension: extension})}}
  end
end
