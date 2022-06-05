defmodule FlowitScaffold.Event.UserAdded do
  @derive Jason.Encoder
  defstruct [:stream_id, :email]
end


