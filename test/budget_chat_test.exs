defmodule BudgetChatTest do
  require Logger
  use ExUnit.Case

  alias Protohackers.BudgetChat.Room

  setup do
    # Supervisor will handle restarting, so we
    # kill to reset the state.
    GenServer.stop(BudgetChat.Room, :normal)
  end

  defp connect() do
    :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false, packet: :line, reuseaddr: true)
  end

  defp connect_skip_welcome() do
    {:ok, socket} = connect()
    assert :gen_tcp.recv(socket, 0) == {:ok, "Welcome to budgetchat! What shall I call you?\n"}
    {:ok, socket}
  end

  defp connect_with_name(name) do
    {:ok, socket} = connect_skip_welcome()
    assert :gen_tcp.send(socket, "#{name}\n") == :ok
    {:ok, socket}
  end

  defp connect_with_name_and_presence(name, existing_names) do
    {:ok, socket} = connect_with_name(name)
    assert :gen_tcp.recv(socket, 0) == {:ok, "* The room contains: #{Enum.join(existing_names, ", ")}\n"}
    {:ok, socket}
  end

  test "clients are welcomed" do
    {:ok, socket} = connect()
    assert :gen_tcp.recv(socket, 0) == {:ok, "Welcome to budgetchat! What shall I call you?\n"}
  end

  test "can register with new name" do
    {:ok, socket} = connect_skip_welcome()
    assert :gen_tcp.send(socket, "bob\n") == :ok
    assert :gen_tcp.recv(socket, 0) == {:ok, "* The room contains: \n"}
    assert Room.client_names() == ["bob"]
  end

  test "new clients are notified of existing clients" do
    connect_with_name("alice")
    {:ok, socket} = connect_with_name("bob")
    assert :gen_tcp.recv(socket, 0) == {:ok, "* The room contains: alice\n"}
    assert Room.client_names() == ["bob", "alice"]
  end

  test "connected clients are notified of new user" do
    {:ok, socket} = connect_with_name_and_presence("alice", [])
    connect_with_name("bob")
    assert :gen_tcp.recv(socket, 0) == {:ok, "* bob has entered the room\n"}
  end
end
