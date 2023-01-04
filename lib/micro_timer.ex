defmodule MicroTimer do
  alias MicroTimer.Native
  alias MicroTimer.Native.ResourceHandle

  @units [:second, :millisecond, :microsecond, :nanosecond]

  @type time_unit :: :second | :millisecond | :microsecond | :nanosecond

  @type duration :: pos_integer()

  @type duration_and_unit :: {pos_integer(), time_unit()}

  @type callable :: {module(), function_name :: atom(), args :: list()} | function()

  @type timer_ref :: MicroTimer.Native.ResourceHandle.t()

  @doc """
  `sleep/1` suspends the process calling this function for `duration`.

  Naturally, this function does not return immediately and is not interruptable.

  If `duration` is a positive integer, it represent the number of nanoseconds
  that `sleep/1` should wait, if it is the atom `:infinity` it suspends the process
  forver, if it is a  two elements tuple, the first element must be a positive
  integer, the second an atom representing one of the `t:time_unit/0` units
  """
  @spec sleep(:infinity | duration | duration_and_unit) :: :ok
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

  @doc """
  Evaluates `callable` after `duration`.

  `callable` can be either a triplet `{module, function, args}` or a function reference.

  Returns a `t:timer_ref()/0` taht can be passed to `cancel/1`.
  """
  @spec apply_after(duration() | duration_and_unit(), callable()) :: {:ok, timer_ref()}
  def apply_after(duration, callable)

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

  @doc """
  Evaluates `callable` repeatedly at intervals of `duration`.

  `callable` can be either a triplet `{module, function, args}` or a function reference.

  Returns a `t:timer_ref()/0` taht can be passed to `cancel/1`.
  """
  @spec apply_interval(duration() | duration_and_unit(), callable()) :: {:ok, timer_ref()}
  def apply_interval(duration, callable)

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

  @doc """
  `exit_after/2` sends an exit signal with reason `reason` to `self()`.

  Returns a `t:timer_ref()/0` taht can be passed to `cancel/1`.
  """
  @spec exit_after(duration() | duration_and_unit(), atom) :: {:ok, timer_ref()}
  def exit_after(duration, reason) when is_atom(reason), do: exit_after(duration, self(), reason)

  def exit_after({duration, unit}, pid, reason)
      when is_integer(duration) and unit in @units and is_pid(pid) do
    exit_after(to_nanoseconds(duration, unit), pid, reason)
  end

  @doc """
  `exit_after/3` sends an exit signal with reason `reason` to `pid`, which can
  be a local process identifier or an atom of a registered name.

  Returns a `t:timer_ref()/0` taht can be passed to `cancel/1`.

  `exit_after/2` is the same as `exit_after(duration, self(), reason)`.
  """
  @spec exit_after(duration | duration_and_unit, pid, atom) :: {:ok, timer_ref()}
  def exit_after(duration, pid, reason)
      when is_integer(duration) and is_pid(pid) and duration > 0 do
    apply_after(duration, fn -> Process.exit(pid, reason) end)
  end

  @doc """

  `kill_after/1` is the same as `exit_after(duration, self(), :kill)`.

  `kill_after/2` is the same as `exit_after(duration, pid, :kill)`.

  """
  @spec kill_after(duration() | duration_and_unit(), pid) :: {:ok, timer_ref()}
  def kill_after(duration, pid \\ self())

  def kill_after(duration, pid)
      when is_integer(duration) and duration > 0 and is_pid(pid),
      do: exit_after(duration, pid, :kill)

  def kill_after({duration, unit}, pid)
      when is_integer(duration) and duration > 0 and unit in @units and is_pid(pid),
      do: exit_after(to_nanoseconds(duration, unit), pid, :kill)

  @doc """
  Cancels a previously requested time-out. `t:timer_ref/0` is a unique timer
  reference returned by the related timer function.
  """
  @spec cancel(timer_ref()) :: {:ok, :cancel} | {:error, term()}
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
