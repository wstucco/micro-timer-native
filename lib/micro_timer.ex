defmodule MicroTimer do
  @units [:nanosecond, :microsecond, :millisecond, :second, :minute, :hour]
  @table_name :___micro_timers___

  def sleep({duration, unit}) when is_integer(duration) and unit in @units do
    nanoseconds = to_nano(duration, unit)
    sleep(nanoseconds)
  end

  def sleep(nanoseconds) when is_integer(nanoseconds) do
    do_sleep(nanoseconds)
  end

  def interval({duration, unit}) when is_integer(duration) and unit in @units do
    nanoseconds = to_nano(duration, unit)
    interval(nanoseconds)
  end

  def interval(nanoseconds) when is_integer(nanoseconds) do
    pid =
      spawn(fn ->
        do_interval(nanoseconds)
      end)

    ref = make_ref()
    :ets.insert(ref_table(), {ref, pid})
    ref
  end

  def cancel_interval(ref) when is_reference(ref) do
    case :ets.lookup(ref_table(), ref) do
      [{^ref, pid}] -> Process.exit(pid, :kill)
      [] -> :error
    end
  end

  defp to_nano(duration, :nanosecond), do: duration
  defp to_nano(duration, :microsecond), do: duration * 1_000
  defp to_nano(duration, :millisecond), do: duration * 1_000_000
  defp to_nano(duration, :second), do: duration * 1_000_000_000
  defp to_nano(duration, :minute), do: duration * 60_000_000_000
  defp to_nano(duration, :hour), do: duration * 3_600_000_000_000

  defp do_sleep(duration) do
    MicroTimer.Native.sleep(duration)

    pid = self()

    receive do
      {^pid, :ok} = message ->
        IO.inspect({:recevied, message})
    end
  end

  defp do_interval(duration) do
    do_sleep(duration)
    do_interval(duration)
  end

  defp ref_table do
    if :ets.whereis(@table_name) === :undefined do
      :ets.new(@table_name, [:set, :private, :named_table])
    end

    @table_name
  end
end
