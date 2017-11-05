defmodule SerdelTest do
  use ExUnit.Case
  doctest Serdel

  test "greets the world" do
    assert Serdel.hello() == :world
  end
end
