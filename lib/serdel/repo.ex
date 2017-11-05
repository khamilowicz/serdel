defmodule Serdel.Repo do
  @moduledoc """
  Available stores:
  - :local
  """

  alias __MODULE__

  defmacro __using__(opts) do
    store =
      Keyword.get(opts, :store) ||
        raise """
        Option `store` is required.
        """

    store_module = store_module(store)

    quote location: :keep do
      use unquote(store_module), unquote(opts)
      @store unquote(store_module)
    end
  end

  defp store_module(:local), do: Repo.Local

  defp store_module(store) do
    raise """
    Store `#{store}` is not supported.

    Available `store` options are:
    - :local
    """
  end
end
