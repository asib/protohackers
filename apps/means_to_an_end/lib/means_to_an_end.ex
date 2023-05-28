defmodule MeansToAnEnd do
  @moduledoc """
  Documentation for `MeansToAnEnd`.
  """
  require Logger

  use GenServer, restart: :permanent

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(port: port) do
    {:ok, socket} =
      :gen_tcp.listen(port,
        mode: :binary,
        active: true,
        exit_on_close: false,
        reuseaddr: true
      )

    Logger.info("listening on #{port}")

    {:ok, socket, {:continue, :accept}}
  end

  @impl true
  @spec handle_continue(:accept, :gen_tcp.socket()) ::
          {:noreply, :gen_tcp.socket(), {:continue, :accept}}
  def handle_continue(:accept, socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info("client connected: #{inspect(client)}")

    {:ok, pid} = DynamicSupervisor.start_child(MeansToAnEnd.ClientSupervisor, MeansToAnEnd.Client)
    :ok = :gen_tcp.controlling_process(client, pid)

    {:noreply, socket, {:continue, :accept}}
  end
end
