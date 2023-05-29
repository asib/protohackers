defmodule Protohackers.VoraciousCodeStorage.Client do
  use GenServer, restart: :permanent

  defstruct [:socket]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(tcp_socket: socket) do
    {:ok, %__MODULE__{socket: socket}, {:continue, :ready}}
  end

  def handle_continue(:ready, state) do
    :ok = :gen_tcp.send(state.socket, "READY\n")

    {:noreply, state}
  end
end
