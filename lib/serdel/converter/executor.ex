defmodule Serdel.Converter.Executor do
  def execute(conversion, options \\ %{}) do
    %{conversion | file: Serdel.File.extract_meta(conversion.file)}
    do_execute(conversion, &execute_conversion(&1, &2, &3, options), fn %{file_name: fname}, _ -> fname end)
  end

  def async_execute(conversion, options \\ %{}) do
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

  defp execute_async_conversion(%Serdel.File{} = file, conversion, name_fun, opts) do
    {:ok, server} = Supervisor.start_child(Serdel.Converter.ExecutorSupervisor, [opts])

    {:ok, file_ident} = request_async_conversion(server, file, conversion, name_fun, opts)

    {:ok, {server, file_ident}}
  end

  defp execute_async_conversion({server, file_promise}, conversion, name_fun, opts) do
    {:ok, new_file_ident} =
      request_async_conversion(server, file_promise, conversion, name_fun, opts)

    {:ok, {server, new_file_ident}}
  end

  defp request_async_conversion(server, file_or_promise, conversion, name_fun, opts) do
    Serdel.Converter.ExecutorServer.insert(server, file_or_promise, fn file, file_promise ->
      if opts[:stream], do: send(opts[:stream], {Serdel.Converter, file_promise, :started})
      {:ok, res} = execute_conversion(file, %{conversion | file: file}, name_fun, opts)

      if opts[:stream],
      do: send(opts[:stream], {Serdel.Converter, file_promise, {:finished, res}})

      {:ok, res}
    end)
  end

  defp collect_and_assign_meta({:ok, file}, meta) do
    meta = do_collect_and_assign_meta(meta, file, Map.to_list(file.meta))
    {:ok, %{file | meta: Enum.into(meta, %{})}}
  end

  defp collect_and_assign_meta(other, _), do: other

  defp do_collect_and_assign_meta([], file, acc), do: acc

  defp do_collect_and_assign_meta([{key, {m, f, a}} | meta], file, acc) do
    {:ok, meta_res} = apply(m, f, [file | a])
    do_collect_and_assign_meta(meta, file, [{key, meta_res} | acc])
  end

  defp do_collect_and_assign_meta([{key, fun} | meta], file, acc) when is_function(fun) do
    {:ok, meta_res} = fun.(file)
    do_collect_and_assign_meta(meta, file, [{key, meta_res} | acc])
  end

  defp do_collect_and_assign_meta([{key, val} | meta], file, acc) do
    do_collect_and_assign_meta(meta, file, [{key, val} | acc])
  end

  defp execute_conversion(
    input_file,
    %{repo: repo, file: file, transformations: [], meta: meta},
    name_fun,
    options
  ) do
    %{input_file | file_name: name_fun.(file, file.meta)}
    |> repo.save()
    |> collect_and_assign_meta(meta)
  end

  defp execute_conversion(
    input_file,
    %{
      repo: repo,
      file: file,
      transformations: [{transformer, args} | transformations]
    } = conversion,
    name_fun,
    options
  ) do
    {:ok, temp_file} = Serdel.TempFile.new()
    :ok = transformer.transform(%{input: input_file, output: temp_file}, args)
    execute_conversion(temp_file, %{conversion | transformations: transformations}, name_fun, options)
  end

  defp traverse_versions(%{versions: versions, file: file}, callback) do
    versions
    |> Enum.map(fn {_version_key, %{conversion: conversion, name_fun: name_fun}} ->
      callback.(%{conversion | file: file}, name_fun)
    end)
    |> Enum.reduce(%{}, &Map.merge/2)
  end
end
