defmodule MicroTimer.Native.ResourceHandle do
  defstruct [
    # The actual NIF Resource.
    resource: nil,
    # Normally the compiler will happily do stuff like inlining the
    # resource in attributes. This will convert the resource into an
    # empty binary with no warning. This will make that harder to
    # accidentaly do.
    # It also serves as a handy way to tell file handles apart.
    reference: nil
  ]

  @type t :: %__MODULE__{}

  def wrap(resource) do
    %__MODULE__{
      resource: resource,
      reference: make_ref()
    }
  end
end

defimpl Inspect, for: MicroTimer.Native.ResourceHandle do
  import Inspect.Algebra

  def inspect(dict, opts) do
    concat(["#MicroTimer.Native.ResourceHandle<", to_doc(dict.reference, opts), ">"])
  end
end
