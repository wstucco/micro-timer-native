defmodule Test do
  def sleep(duration) do
    :timer.tc(fn -> MicroTimer.sleep(duration) end)
  end

  def multiple_processes do
    p1 =
      spawn(fn ->
        f = fn g, c ->
          IO.puts("p1 counter = #{c}")
          MicroTimer.sleep({5, :second})
          g.(g, c + 1)
        end

        f.(f, 0)
      end)

    p2 =
      spawn(fn ->
        f = fn g, c ->
          IO.puts("p2 counter = #{c}")
          MicroTimer.sleep({2, :second})
          g.(g, c + 1)
        end

        f.(f, 0)
      end)

    [p1, p2]
  end

  def interval do
    MicroTimer.interval({2, :second})
  end
end
