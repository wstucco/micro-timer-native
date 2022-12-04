defmodule MicroTimer.Native do
  @version Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :micro_timer_native,
    crate: :timer,
    base_url: "https://github.com/wstucco/micro-timer-native/releases/download/v#{@version}",
    version: @version

  def sleep(duration) when is_integer(duration), do: sleep(duration, self())
  def sleep(duration, pid) when is_integer(duration) and is_pid(pid), do: error()

  def interval(duration, pid), do: interval(duration, pid, -1)

  def interval(duration, pid, times)
      when is_number(duration) and is_pid(pid) and is_number(times),
      do: error()

  def cancel(resource) when is_reference(resource), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
