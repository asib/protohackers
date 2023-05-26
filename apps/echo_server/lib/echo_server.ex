defmodule EchoServer do
  @moduledoc """
  Documentation for `EchoServer`.
  """

  require Logger

  @spec accept(integer()) :: nil
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: false, exit_on_close: false, reuseaddr: true])

    Logger.info("listening on #{port}")

    loop_acceptor(socket)
  end

  @spec loop_acceptor(:gen_tcp.socket()) :: nil
  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(EchoServer.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  @spec serve(:gen_tcp.socket()) :: nil
  defp serve(socket) do
    socket
    |> read_all()
    |> write_all(socket)

    serve(socket)
  end

  @spec read_all(:gen_tcp.socket()) :: binary()
  defp read_all(socket) do
    {:ok, packet} = :gen_tcp.recv(socket, 0)
    packet
  end

  @spec write_all(binary(), :gen_tcp.socket()) :: :ok
  def write_all(data, socket) do
    :gen_tcp.send(socket, data)
  end
end
