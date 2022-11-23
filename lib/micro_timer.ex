defmodule MicroTimer do
  @units [:nanosecond, :microsecond, :millisecond, :second, :minute, :hour]
  @table_name :___micro_timers___

  def sleep({duration, unit}) when is_integer(duration) and unit in @units do
    nanoseconds = to_nano(duration, unit)
    sleep(nanoseconds)
  end

  def sleep(nanoseconds) when is_integer(nanoseconds) do
    do_sleep(nanoseconds)
    pid = self()

    receive do
      {^pid, :ok} = message ->
        IO.inspect({:slept, message})
    end
  end

  def sleep(:infinity) do
    :timer.sleep(:infinity)
  end

  def apply_after({duration, unit}, callable) when is_integer(duration) and unit in @units do
    apply_after(to_nano(duration, unit), callable)
  end

  def apply_after(time, {module, function_name, args})
      when is_atom(module) and is_atom(function_name) and is_list(args) and is_integer(time) do
    pid =
      spawn(fn ->
        receive do
          :ok -> apply(module, function_name, args)
        end
      end)

    do_sleep(time)
    cancellable_for(pid)
  end

  def interval({duration, unit}) when is_integer(duration) and unit in @units do
    nanoseconds = to_nano(duration, unit)
    interval(nanoseconds)
  end

  def interval(nanoseconds) when is_integer(nanoseconds) do
    pid = spawn(fn -> do_interval(nanoseconds) end)
    cancellable_for(pid)
  end

  @spec cancel(reference()) :: {:ok, :cancel} | {:error, :invalid_reference}
  def cancel(reference) when is_reference(reference) do
    case :ets.lookup(ref_table(), reference) do
      [{^reference, pid, receiver}] ->
        send(receiver, {pid, :cancel})
        :ets.delete(ref_table(), reference)
        {:ok, :cancel}

      [] ->
        {:error, :invalid_reference}
    end
  end

  defp cancellable_for(pid) when is_pid(pid) do
    receiver = receiver_for(pid)
    ref = make_ref()
    :ets.insert(ref_table(), {ref, pid, receiver})
    {:ok, ref}
  end

  defp receiver_for(pid) when is_pid(pid) do
    spawn(fn ->
      receive do
        {^pid, :ok} ->
          send(pid, :ok)

        {^pid, :cancel} ->
          Process.exit(pid, :kill)
      end
    end)
  end

  defp to_nano(duration, :nanosecond), do: duration
  defp to_nano(duration, :microsecond), do: duration * 1_000
  defp to_nano(duration, :millisecond), do: duration * 1_000_000
  defp to_nano(duration, :second), do: duration * 1_000_000_000
  defp to_nano(duration, :minute), do: duration * 60_000_000_000
  defp to_nano(duration, :hour), do: duration * 3_600_000_000_000

  defp do_sleep(duration) do
    MicroTimer.Native.sleep(duration)
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
