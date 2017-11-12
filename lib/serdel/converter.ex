defmodule Serdel.Converter do
  defstruct versions: %{}, root: nil, transformations: [], repo: nil, file: nil, meta: []

  defmodule Version do
    defstruct [:conversion, :name_fun]
  end

  defdelegate execute(conversion), to: Serdel.Converter.Executor
  defdelegate async_execute(conversion, opts \\ []), to: Serdel.Converter.Executor

  def info({server, file_id}) do
    Serdel.Converter.ExecutorServer.info(server, file_id)
  end

  def change(converter_or_file, name \\ nil)

  def change(%__MODULE__{} = converter, _name) do
    converter
  end

  def change(file, name) do
    %__MODULE__{root: name, file: file}
  end

  def put_transformation(conversion, transformer, args) do
    update_in(conversion.transformations, &List.insert_at(&1, -1, {transformer, args}))
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

  def put_meta(%{name: name} = conversion, name, meta) do
    %{conversion | meta: meta}
  end

  def put_meta(conversion, name, meta) do
    update_in(conversion.versions[name].conversion.meta, &Keyword.merge(meta, &1))
  end
end
