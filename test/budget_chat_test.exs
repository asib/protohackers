defmodule BudgetChatTest do
  use ExUnit.Case

  test "clients are welcomed" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false, packet: :line)

    assert :gen_tcp.recv(socket, 0) == {:ok, "Welcome to budgetchat! What shall I call you?\n"}
  end
end
