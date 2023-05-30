defmodule Protohackers.VoraciousCodeStorage.FileSystem do
  use GenServer, restart: :permanent
  use TypedStruct
  require Logger

  # alias Protohackers.VoraciousCodeStorage.CommandParser
  @type revision() :: integer()
  @type dir_path() :: String.t()

  defmodule File do
    typedstruct do
      field(:name, String.t(), enforce: true)
      field(:revisions, %{FileSystem.revision() => binary()}, enforce: true)
    end
  end

  @type files_map() :: %{dir_path() => list(File.t())}

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

  @impl true
  def handle_call({:put, path, data}, _from, %{files: files} = state) do
    {file_name, dir_parts} =
      path
      |> String.split("/", trim: true)
      |> List.pop_at(-1)

    dir_path = "/" <> Enum.join(dir_parts, "/")

    new_files =
      Map.update(
        files,
        dir_path,
        [fresh_file(file_name, data)],
        &update_directory(&1, file_name, data)
      )

    {:reply, 1, %{state | files: new_files}}
  end

  @spec fresh_file(String.t(), binary()) :: File.t()
  defp fresh_file(name, data), do: %File{name: name, revisions: %{1 => data}}

  @spec update_directory(list(File.t()), String.t(), binary()) :: list(File.t())
  defp update_directory(existing_files, file_name, data) do
    case existing_files |> Enum.find_index(fn file -> file.name == file_name end) do
      nil ->
        [update_file(%File{name: file_name, revisions: %{}}, data) | existing_files]

      index ->
        List.update_at(existing_files, index, &update_file(&1, data))
    end
  end

  @spec update_file(File.t(), binary()) :: File.t()
  def update_file(%File{revisions: revisions} = file, new_data) do
    new_revision =
      (revisions
       |> Map.keys()
       |> Enum.max(fn -> 0 end)) + 1

    %File{file | revisions: Map.put(revisions, new_revision, new_data)}
  end

  @spec list(String.t()) :: list(File.t())
  def list(path) do
    GenServer.call(__MODULE__, {:list, path})
  end

  @spec put(String.t(), binary()) :: {:ok, revision()}
  def put(path, data) do
    GenServer.call(__MODULE__, {:put, path, data})
  end
end
