defmodule Protohackers.BudgetChat.Client do
  use GenServer, restart: :transient

  use TypedStruct
  require Logger
  alias Protohackers.BudgetChat.Room

  typedstruct do
    field(:name, String.t() | nil, default: nil)
    field(:mode, :awaiting_name | :active, default: :awaiting_name)
    field(:tcp_socket, :gen_tcp.socket(), enforce: true)
  end

  def server_socket_opts do
    [packet: :line]
  end

  def applications do
    [Room]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(tcp_socket: socket) do
    {:ok, %__MODULE__{tcp_socket: socket}, {:continue, :welcome}}
  end

  @impl true
  def handle_info({:tcp, client_socket, client_name}, %__MODULE__{mode: :awaiting_name} = state) do
    stripped_client_name = String.trim_trailing(client_name)

    if stripped_client_name =~ ~r/^[a-zA-Z0-9]+$/ do
      Logger.info("registering client #{inspect(stripped_client_name)}")
      {:ok, existing_users} = Room.register(stripped_client_name)

      :ok =
        :gen_tcp.send(
          client_socket,
          "* The room contains: #{existing_users |> Enum.join(", ")}\n"
        )

      {:noreply, %{state | mode: :active, name: stripped_client_name}}
    else
      Logger.info("illegal name #{inspect(stripped_client_name)}")
      {:stop, :normal, nil}
    end
  end

  @impl true
  def handle_info({:tcp, _client_socket, message}, %__MODULE__{mode: :active} = state) do
    :ok = Room.send_message(self(), state.name, message)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("#{inspect(client_socket)}: client closed connection")

    :ok = :gen_tcp.close(client_socket)

    if state.mode == :active do
      :ok = Room.unregister(self(), state.name)
    end

    {:stop, :normal, nil}
  end

  @impl true
  def handle_cast({:new_client, client_name}, state) do
    Logger.info("informing existing clients of new client")

    :ok = :gen_tcp.send(state.tcp_socket, "* #{client_name} has entered the room\n")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:new_message, from, message}, state) do
    # `message` contains a newline, so no need to append one.
    :ok = :gen_tcp.send(state.tcp_socket, "[#{from}] #{message}")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:disconnected, name}, state) do
    Logger.info("informing clients that someone left")

    :ok = :gen_tcp.send(state.tcp_socket, "* #{name} has left the room\n")

    {:noreply, state}
  end

  @impl true
  def handle_continue(:welcome, state) do
    Logger.debug("sending welcome message")
    :ok = :gen_tcp.send(state.tcp_socket, "Welcome to budgetchat! What shall I call you?\n")

    {:noreply, state}
  end
end
