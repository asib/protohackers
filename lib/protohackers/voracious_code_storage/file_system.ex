defmodule Protohackers.VoraciousCodeStorage.FileSystem do
  use GenServer, restart: :permanent
  use TypedStruct
  require Logger

  # alias Protohackers.VoraciousCodeStorage.CommandParser

  defmodule File do
    typedstruct do
      field(:name, String.t(), enforce: true)
      field(:revisions, %{integer() => String.t()}, enforce: true)
    end
  end

  @type files_map() :: %{String.t() => list(File.t())}

  typedstruct do
    field(:files, files_map(), enforce: true)
  end

  def start_link(opts \\ [files: %{}]) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(files: files) do
    {:ok, %__MODULE__{files: files}}
  end

  @impl true
  def handle_call({:list, path}, _from, %{files: files} = state) do
    files_in_path =
      case Map.fetch(files, path) do
        {:ok, files_in_path} -> files_in_path
        :error -> []
      end

    {:reply, files_in_path, state}
  end

  @spec list(String.t()) :: list(File.t())
  def list(path) do
    GenServer.call(__MODULE__, {:list, path})
  end
end
