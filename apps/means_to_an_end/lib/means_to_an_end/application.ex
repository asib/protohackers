defmodule MeansToAnEnd.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "5000")
    Logger.configure(level: :info)

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: MeansToAnEnd.ClientSupervisor},
      {MeansToAnEnd, [port: port]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MeansToAnEnd.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
