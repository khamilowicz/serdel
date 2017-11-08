defmodule Serdel.Converter.Executor do
  def execute(conversion) do
    %{conversion | file: Serdel.File.extract_meta(conversion.file)}
    do_execute(conversion, &execute_conversion/3, fn %{file_name: fname}, _ -> fname end)
  end

  def async_execute(conversion, options) do
    do_execute(conversion, &execute_async_conversion(&1, &2, &3, options), fn %{file_name: fname},
                                                                              _ ->
      fname
    end)
  end

  defp do_execute(%{root: root, file: file} = root_conversion, conversion_fun, name_fun) do
    case conversion_fun.(file, root_conversion, name_fun) do
      {:ok, new_file} ->
        %{
          root => {:ok, new_file},
          versions: traverse_versions(
            %{root_conversion | file: new_file},
            &do_execute(&1, conversion_fun, &2)
          )
        }

      other ->
        %{root => other}
    end
  end

  defp execute_async_conversion(%Serdel.File{} = file, root_conversion, name_fun, opts) do
    {:ok, server} = Serdel.Converter.ExecutorServer.start_link([])

    {:ok, file_ident} =
      Serdel.Converter.ExecutorServer.insert(server, file, fn input, file, ident ->
        if opts[:stream], do: send(opts[:stream], {Serdel.Converter, ident, :started})
        {:ok, res} = execute_conversion(input, %{root_conversion | file: file}, name_fun)
        if opts[:stream], do: send(opts[:stream], {Serdel.Converter, ident, {:finished, res}})
        {:ok, res}
      end)

    {:ok, {server, file_ident}}
  end

  defp execute_async_conversion({server, file_ident}, root_conversion, name_fun, opts) do
    {:ok, new_file_ident} =
      Serdel.Converter.ExecutorServer.insert(server, file_ident, fn input, file, ident ->
        if opts[:stream], do: send(opts[:stream], {Serdel.Converter, ident, :started})
        {:ok, res} = execute_conversion(input, %{root_conversion | file: file}, name_fun)
        if opts[:stream], do: send(opts[:stream], {Serdel.Converter, ident, {:finished, res}})
        {:ok, res}
      end)

    {:ok, {server, new_file_ident}}
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
         } = conv,
         name_fun
       ) do
    {:ok, temp_file} = Serdel.TempFile.new()
    :ok = transformer.transform(%{input: input_file, output: temp_file}, args)
    repo.save(%{temp_file | file_name: name_fun.(file, input_file.meta)})
  end

  defp traverse_versions(%{versions: versions, file: file}, callback) do
    versions
    |> Enum.map(fn {k, %{conversion: conversion, name_fun: name_fun}} ->
         callback.(%{conversion | file: file}, name_fun)
       end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end
end
