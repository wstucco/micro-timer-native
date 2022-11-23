defmodule MicroTimer.Native do
  use Rustler, otp_app: :micro_timer_native, crate: :timer

  def sleep(nanoseconds) when is_integer(nanoseconds), do: error()
  def interval(nanoseconds) when is_integer(nanoseconds), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
