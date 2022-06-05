defmodule FlowitScaffold.Command.AddUser  do
  defstruct [:stream_id, :email, :email_is_available]

  defimpl FlowitScaffold.CommandDispatcher, for: FlowitScaffold.Command.AddUser do
    def dispatch(command) do
      FlowitScaffold.Aggregate.UserAggregate.execute(command)
    end
  end

end

