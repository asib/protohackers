defmodule Protohackers.UDPServer do
  require Logger

  use GenServer, restart: :permanent

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(port: port, client_handler: client_handler) do
    listen_opts = [mode: :binary, active: true]

    {:ok, socket} = :gen_udp.open(port, listen_opts)

    Logger.info("listening on #{port}")

    applications =
      case Kernel.function_exported?(client_handler, :applications, 0) do
        true -> Kernel.apply(client_handler, :applications, [])
        false -> []
      end

    {:ok, client_supervisor_pid} = Supervisor.start_link(applications, strategy: :one_for_one)
    {:ok, client_handler_pid} = Supervisor.start_child(client_supervisor_pid, client_handler)

    :ok = :gen_udp.controlling_process(socket, client_handler_pid)

    {:ok, nil}
  end
end
