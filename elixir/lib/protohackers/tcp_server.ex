defmodule Protohackers.TCPServer do
  require Logger

  use GenServer, restart: :permanent

  defstruct [:listen_socket, :client_supervisor, :client_handler]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(port: port, client_handler: client_handler, socket_opts: socket_opts) do
    default_listen_opts = [mode: :binary, active: true, exit_on_close: false, reuseaddr: true]

    listen_opts =
      Keyword.merge(default_listen_opts, socket_opts, fn _key, _default_value, argument_value ->
        argument_value
      end)

    {:ok, socket} = :gen_tcp.listen(port, listen_opts)

    Logger.info("listening on #{port}")

    {:ok, client_supervisor_pid} = DynamicSupervisor.start_link(strategy: :one_for_one)

    if Kernel.function_exported?(client_handler, :applications, 0) do
      Kernel.apply(client_handler, :applications, [])
      |> Enum.each(fn app ->
        Logger.info("starting #{inspect(app)}")
        DynamicSupervisor.start_child(client_supervisor_pid, app)
      end)
    end

    {:ok,
     %__MODULE__{
       listen_socket: socket,
       client_supervisor: client_supervisor_pid,
       client_handler: client_handler
     }, {:continue, :accept}}
  end

  @impl true
  def handle_continue(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state.listen_socket)

    Logger.info("client connected: #{inspect(client)}")

    {:ok, pid} =
      DynamicSupervisor.start_child(
        state.client_supervisor,
        {state.client_handler, [tcp_socket: client]}
      )

    :ok = :gen_tcp.controlling_process(client, pid)

    {:noreply, state, {:continue, :accept}}
  end
end
