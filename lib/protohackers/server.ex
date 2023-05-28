defmodule Protohackers.Server do
  require Logger

  use GenServer, restart: :permanent

  defstruct [:listen_socket, :client_supervisor, :client_handler]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  @spec init([port: integer(), client_handler: GenServer.name()]) :: {:ok, %__MODULE__{}, {:continue, :accept}}
  def init(port: port, client_handler: client_handler) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: true, exit_on_close: false, reuseaddr: true])

    Logger.info("listening on #{port}")

    {:ok, client_supervisor_pid} = DynamicSupervisor.start_link(strategy: :one_for_one)

    {:ok, %__MODULE__{listen_socket: socket, client_supervisor: client_supervisor_pid, client_handler: client_handler}, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state.socket)

    Logger.info("client connected: #{inspect(client)}")

    {:ok, pid} = DynamicSupervisor.start_child(state.client_supervisor, state.client_handler)
    :ok = :gen_tcp.controlling_process(client, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
