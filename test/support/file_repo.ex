defmodule Serdel.Test.FileRepo do
  use Serdel.Repo,
    store: :local,
    storage_dir: "./test/support/uploads/"
end
