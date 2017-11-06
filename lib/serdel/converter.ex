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
    new_version = put_in version.conversion.repo, repo
    update_in conversion.versions, &Map.put(&1, name, new_version)
  end

  def execute(conversion) do
    {:ok, list_versions(conversion) }
  end

  defp list_versions(conversion) do
    conversion.versions
    |> Enum.map(fn({key, %{conversion: %{file: file}}}) -> {key, file} end)
    |> Enum.into(%{conversion.root => conversion.file})
  end
end
