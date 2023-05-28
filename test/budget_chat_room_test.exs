defmodule BudgetChatRoomTest do
  use ExUnit.Case

  alias Protohackers.BudgetChat.Room
  alias Protohackers.BudgetChat.User

  test "can register new client" do
    {:ok, room_pid} = Room.start_link()

    Room.register("bob")

    assert :sys.get_state(room_pid) == %Room{clients: [%User{pid: self(), name: "bob"}]}
  end
end
