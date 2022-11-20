defmodule MicroTimerNativeTest do
  use ExUnit.Case
  doctest MicroTimerNative

  test "greets the world" do
    assert MicroTimerNative.hello() == :world
  end
end
