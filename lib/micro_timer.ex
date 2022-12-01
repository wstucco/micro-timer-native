defmodule MicroTimer do
  alias MicroTimer.Native
  alias MicroTimer.Native.ResourceHandle

  @units [:second, :millisecond, :microsecond, :nanosecond]

  def sleep({duration, unit}) when is_integer(duration) and unit in @units do
    nanos = to_nanoseconds(duration, unit)
    sleep(nanos)
  end

  def sleep(duration) when is_integer(duration) and duration > 0 do
    pid = self()

    Native.sleep(duration, pid)

    receive do
      {^pid, :ok} -> :ok
    end
  end

  def sleep(:infinity) do
    :timer.sleep(:infinity)
  end

  def apply_after({duration, unit}, callable) when is_integer(duration) and unit in @units do
    apply_after(to_nanoseconds(duration, unit), callable)
  end

  def apply_after(duration, {module, function_name, args})
      when is_atom(module) and is_atom(function_name) and is_list(args) and is_integer(duration) do
    fun = fn -> apply(module, function_name, args) end
    apply_after(duration, fun)
  end

  def apply_after(duration, fun)
      when is_integer(duration) and is_function(fun) and duration > 0 do
    pid = apply_on_tick(fun)
    {:ok, resource} = Native.interval(duration, pid, 1)
    {:ok, ResourceHandle.wrap(resource)}
  end

  def apply_interval({duration, unit}, callable) when is_integer(duration) and unit in @units do
    apply_interval(to_nanoseconds(duration, unit), callable)
  end

  def apply_interval(duration, {module, function_name, args})
      when is_atom(module) and is_atom(function_name) and is_list(args) and is_integer(duration) do
    fun = fn -> apply(module, function_name, args) end
    apply_interval(duration, fun)
  end

  def apply_interval(duration, fun)
      when is_integer(duration) and is_function(fun) and duration > 0 do
    pid = apply_on_tick(fun)
    {:ok, resource} = Native.interval(duration, pid)
    {:ok, ResourceHandle.wrap(resource)}
  end

  def exit_after(duration, pid, reason \\ :normal)

  def exit_after({duration, unit}, pid, reason)
      when is_integer(duration) and unit in @units and is_pid(pid) do
    exit_after(to_nanoseconds(duration, unit), pid, reason)
  end

  def exit_after(duration, pid, reason)
      when is_integer(duration) and is_pid(pid) and duration > 0 do
    apply_after(duration, fn -> Process.exit(pid, reason) end)
  end

  def cancel(%ResourceHandle{resource: resource}) do
    Native.cancel(resource)
  end

  defp apply_on_tick(fun) when is_function(fun) do
    spawn(fn ->
      pid = self()

      loop = fn f ->
        receive do
          {^pid, :tick} ->
            fun.()
            f.(f)

          {^pid, :cancel} ->
            :ok
        end
      end

      loop.(loop)
    end)
  end

  defp to_nanoseconds(duration, :nanosecond), do: duration
  defp to_nanoseconds(duration, :microsecond), do: duration * 1_000
  defp to_nanoseconds(duration, :millisecond), do: duration * 1_000_000
  defp to_nanoseconds(duration, :second), do: duration * 1_000_000_000
end
