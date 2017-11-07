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
    put_in(conversion.versions[name], %Version{
      conversion: %{conv | root: name},
      name_fun: name_fun
    })
  end

  def put_repo(%{root: name} = conversion, name, repo) do
    %{conversion | repo: repo}
  end

  def put_repo(conversion, name, repo) do
    put_in(conversion.versions[name].conversion.repo, repo)
  end

  def execute(%{root: root, file: file} = root_conversion, name_fun \\ &default_name_fun/2) do
    case execute_conversion(file, root_conversion, name_fun) do
      {:ok, new_file} ->
        %{
          root => {:ok, new_file},
          versions: traverse_versions(%{root_conversion | file: new_file}, &execute/2)
        }

      other ->
        %{root => other}
    end
  end

  defp traverse_versions(%{versions: versions, file: file}, callback) do
    versions
    |> Enum.map(fn {k, %{conversion: conversion, name_fun: name_fun}} ->
         callback.(%{conversion | file: file}, name_fun)
       end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp execute_conversion(input_file, %{repo: repo, file: file, transformation: nil}) do
    repo.save(%{input_file | file_name: file.file_name})
  end

  defp execute_conversion(
         input_file,
         %{
           repo: repo,
           file: file,
           transformation: {transformer, args}
         },
         name_fun
       ) do
    extension = Path.extname(input_file.file_name)
    {:ok, temp_file} = Serdel.TempFile.new()
    :ok = transformer.transform(%{input: input_file, output: temp_file}, args)
    repo.save(%{temp_file | file_name: name_fun.(file, %{extension: extension})})
  end

  defp default_name_fun(%{file_name: fname}, _), do: fname
end
