defmodule FileSystemTest do
  use ExUnit.Case

  alias Protohackers.VoraciousCodeStorage.FileSystem

  alias Protohackers.VoraciousCodeStorage.FileSystem.{
    File,
    FileListing
  }

  setup do
    start_supervised!({FileSystem, [files_by_path: %{}]})
    :ok
  end

  test "can list files" do
    assert FileSystem.put("/bla.txt", "contents") == {:ok, 1}

    assert FileSystem.list("/") == [
             %FileListing{
               name: "bla.txt",
               revision: 1
             }
           ]
  end

  test "files in other directories are not listed" do
    assert FileSystem.put("/a", "a") == {:ok, 1}
    assert FileSystem.put("/a/b", "b") == {:ok, 1}

    assert FileSystem.list("/") == [
             %FileListing{name: "a", revision: 1}
           ]

    assert FileSystem.list("/a") == [
             %FileListing{name: "b", revision: 1}
           ]

    FileSystem.put("/a/b", "b2")

    assert FileSystem.list("/a") == [
             %FileListing{name: "b", revision: 2}
           ]
  end

  test "can update file" do
    assert FileSystem.put("/a", "initial") == {:ok, 1}
    assert FileSystem.put("/a", "new") == {:ok, 2}

    assert FileSystem.list("/") == [
             %FileListing{
               name: "a",
               revision: 2
             }
           ]
  end

  test "update_file with new revisions adds initial revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{}}, "one") ==
             {%FileSystem.File{name: "a", revisions: %{1 => "one"}}, 1}
  end

  test "update_file adds new revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{1 => "one"}}, "two") ==
             {%FileSystem.File{name: "a", revisions: %{1 => "one", 2 => "two"}}, 2}
  end

  test "can get file without specifying revision" do
    FileSystem.put("/a", "a")
    assert FileSystem.get("/a") == "a"
  end

  test "can get file with specified revision" do
    FileSystem.put("/a", "a")
    FileSystem.put("/a", "b")
    assert FileSystem.get("/a", 1) == "a"
  end

  test "can get file name and directory path from full path" do
    assert FileSystem.file_name_and_directory("/a") == {"/", "a"}
    assert FileSystem.file_name_and_directory("/a/b/c") == {"/a/b", "c"}
  end
end
