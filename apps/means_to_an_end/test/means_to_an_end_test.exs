defmodule MeansToAnEndTest do
  use ExUnit.Case
  doctest MeansToAnEnd

  test "how long to insert 200k" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false)

    IO.inspect(
      :timer.tc(fn ->
        Enum.each(0..500_000, fn n ->
          :ok = :gen_tcp.send(socket, <<?I, n::integer-32-signed-big, n::integer-32-signed-big>>)
        end)

        :gen_tcp.send(socket, <<?Q, 0::integer-32-signed-big, 1_000_000::integer-32-signed-big>>)

        IO.inspect(:gen_tcp.recv(socket, 4))
      end)
    )
  end
end
