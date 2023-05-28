defmodule Protohackers.BudgetChat.Client do
  use GenServer, restart: :transient

  use TypedStruct
  require Logger

  typedstruct do
    field :name, String.t() | nil, default: nil
  end

  def server_socket_opts do
    [packet: :line]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:client_connected, socket}, state) do
    Logger.debug("sending welcome message")
    :ok = :gen_tcp.send(socket, "Welcome to budgetchat! What shall I call you?\n")

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, _state) do
    Logger.info("#{inspect(client_socket)}: client closed connection")

    :ok = :gen_tcp.close(client_socket)

    {:stop, :normal, nil}
  end

  @impl true
  def handle_cast({:client_connected, socket}, state) do
    Logger.debug("sending welcome message")
    :ok = :gen_tcp.send(socket, "Welcome to budgetchat! What shall I call you?\n")

    {:noreply, state}
  end

  @spec client_connected(pid(), :gen_tcp.socket()) :: :ok
  def client_connected(pid, client_socket) do
    Logger.debug("casting welcome message")
    GenServer.cast(pid, {:client_connected, client_socket})
  end
end
