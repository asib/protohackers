defmodule PrimeTimeTest do
  use ExUnit.Case
  doctest PrimeTime

  test "greets the world" do
    assert PrimeTime.hello() == :world
  end
end
