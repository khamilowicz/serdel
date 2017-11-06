defmodule Serdel.ImageInfo do

  alias Serdel.{File, Extractors}

  def extract(%File{} = file, extractor \\ Extractors.ImageMagick) do
    extractor.info(file)
  end

end
