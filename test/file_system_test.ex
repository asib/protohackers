defmodule FileSystemTest do
  use ExUnit.Case

  alias Protohackers.VoraciousCodeStorage.FileSystem

  alias Protohackers.VoraciousCodeStorage.FileSystem.{
    File,
    FileListing
  }

  setup do
    start_supervised!({FileSystem, [files: %{}]})
    :ok
  end

  test "can list files" do
    FileSystem.put("/bla.txt", "contents")

    assert FileSystem.list("/") == [
             %FileListing{
               name: "bla.txt",
               revision: 1
             }
           ]
  end

  test "files in other directories are not listed" do
    FileSystem.put("/a", "a")
    FileSystem.put("/a/b", "b")

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
    FileSystem.put("/a", "initial")
    FileSystem.put("/a", "new")

    assert FileSystem.list("/") == [
             %FileListing{
               name: "a",
               revision: 2
             }
           ]
  end

  test "update_file with new revisions adds initial revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{}}, "one") ==
             %FileSystem.File{name: "a", revisions: %{1 => "one"}}
  end

  test "update_file adds new revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{1 => "one"}}, "two") ==
             %FileSystem.File{name: "a", revisions: %{1 => "one", 2 => "two"}}
  end
end
