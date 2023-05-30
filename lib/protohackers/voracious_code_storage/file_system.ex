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

  defmodule FileListing do
    typedstruct do
      field(:name, String.t(), enforce: true)
      field(:revision, FileSystem.revision(), enforce: true)
    end
  end

  @type files_map() :: %{dir_path() => list(File.t())}

  typedstruct do
    field(:files_by_path, files_map(), enforce: true)
  end

  def start_link(opts \\ [files_by_path: %{}]) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(files_by_path: files_by_path) do
    {:ok, %__MODULE__{files_by_path: files_by_path}}
  end

  @impl true
  def handle_call({:list, path}, _from, %{files_by_path: files_by_path} = state) do
    files_in_path =
      case Map.fetch(files_by_path, path) do
        {:ok, files_in_path} ->
          files_in_path
          |> Enum.map(fn file ->
            %FileListing{name: file.name, revision: file.revisions |> Map.keys() |> Enum.max()}
          end)

        :error ->
          []
      end

    {:reply, files_in_path, state}
  end

  @impl true
  def handle_call({:put, path, data}, _from, %{files_by_path: files_by_path} = state) do
    {dir_path, file_name} = file_name_and_directory(path)

    # Initialise directory if not already done.
    files_by_path = Map.put_new(files_by_path, dir_path, [])

    {new_directory_files, file_revision} =
      update_directory(Map.fetch!(files_by_path, dir_path), file_name, data)

    new_files_by_path = Map.put(files_by_path, dir_path, new_directory_files)
    # new_files =
    #   Map.update(
    #     files,
    #     dir_path,
    #     [fresh_file(file_name, data)],
    #     &update_directory(&1, file_name, data)
    #   )

    {:reply, {:ok, file_revision}, %{state | files_by_path: new_files_by_path}}
  end

  @spec update_directory(list(File.t()), String.t(), binary()) :: {list(File.t()), revision()}
  defp update_directory(existing_files, file_name, data) do
    case existing_files |> Enum.find_index(fn file -> file.name == file_name end) do
      nil ->
        {new_file, new_revision} = update_file(%File{name: file_name, revisions: %{}}, data)
        {[new_file | existing_files], new_revision}

      index ->
        file = Enum.fetch!(existing_files, index)
        {new_file, new_revision} = update_file(file, data)
        {List.replace_at(existing_files, index, new_file), new_revision}
    end
  end

  @spec update_file(File.t(), binary()) :: {File.t(), revision()}
  def update_file(%File{revisions: revisions} = file, new_data) do
    new_revision =
      (revisions
       |> Map.keys()
       |> Enum.max(fn -> 0 end)) + 1

    {%File{file | revisions: Map.put(revisions, new_revision, new_data)}, new_revision}
  end

  @spec file_name_and_directory(String.t()) :: {dir_path(), String.t()}
  def file_name_and_directory(path) do
    {file_name, dir_parts} =
      path
      |> String.split("/", trim: true)
      |> List.pop_at(-1)

    dir_path = "/" <> Enum.join(dir_parts, "/")

    {dir_path, file_name}
  end

  @spec list(String.t()) :: list(FileListing.t())
  def list(path) do
    GenServer.call(__MODULE__, {:list, path})
  end

  @spec put(String.t(), binary()) :: {:ok, revision()}
  def put(path, data) do
    GenServer.call(__MODULE__, {:put, path, data})
  end

  # @spec get(String.t(), revision() | :latest) :: {:ok, String.t()}
end
