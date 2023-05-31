defmodule CommandParserTest do
  use ExUnit.Case, async: true

  import Protohackers.VoraciousCodeStorage.CommandParser
  alias Protohackers.VoraciousCodeStorage.CommandParser

  @help_success_cases [
    {"help", "can parse help"},
    {"help bla bla", "parsing help ignores any input after the command but before the newline"}
  ]

  for {input, case_name} <- @help_success_cases do
    test case_name do
      assert parse_command("#{unquote(input)}") == {:ok, :help}
    end
  end

  @commands_with_path [{:list, CommandParser.List}, {:get, CommandParser.Get}]
  @command_with_path_success_cases [
    {"/bla.txt", "/bla.txt", "can parse file in root"},
    {"/bla-testing_new.txt", "/bla-testing_new.txt", "can parse file with hyphen"},
    {"/.", "/.", "can parse /."}
  ]

  for {command, struct_name} <- @commands_with_path,
      {input, expected, case_name} <- @command_with_path_success_cases do
    test "#{Atom.to_string(command)}: #{case_name}" do
      assert parse_command("#{Atom.to_string(unquote(command))} #{unquote(input)}") ==
               {:ok, %unquote(struct_name){path: unquote(expected)}}
    end
  end

  @put_success_cases [
    {"/bla.txt 5", {"/bla.txt", 5}, "can parse put"},
    {"/test 2b", {"/test", 2}, "ignore characters after length but before newline"},
    {"/test bla", {"/test", 0}, "(1): non-numeric length is parsed as 0"},
    {"/test _", {"/test", 0}, "(2): non-numeric length is parsed as 0"}
  ]

  for {input, {path, length}, case_name} <- @put_success_cases do
    test case_name do
      assert parse_command("put #{unquote(input)}") ==
               {:ok, %CommandParser.Put{path: unquote(path), length: unquote(length)}}
    end
  end

  @incomplete_cases [
    "help",
    "get /bla.txt",
    "list ",
    "put /bla.txt 15",
    "put /bla.txt ddfkdfd"
  ]

  for input <- @incomplete_cases do
    test "incomplete: #{inspect(input)}" do
      assert parse(unquote(input)) == {:error, :no_newline}
    end
  end

  test "list: can parse root" do
    assert parse_command("list /") == {:ok, %CommandParser.List{path: "/"}}
    assert parse_command("list /           ") == {:ok, %CommandParser.List{path: "/"}}
  end

  test "list: illegal usage" do
    assert parse_command("list / abc") == {:error, {:usage, :list}}
    assert parse_command("list a b c") == {:error, {:usage, :list}}
  end

  test "list: illegal dir name" do
    assert parse_command("list abc") == {:error, :illegal_dir_name}
    assert parse_command("list /$^%£&£@") == {:error, :illegal_dir_name}
  end

  test "get: illegal usage" do
    assert parse_command("get /a b c") == {:error, {:usage, :get}}
    assert parse_command("get a b c") == {:error, {:usage, :get}}
  end

  test "get: illegal file name" do
    assert parse_command("get /") == {:error, :illegal_file_name}
    assert parse_command("get /a/") == {:error, :illegal_file_name}
    assert parse_command("get /%") == {:error, :illegal_file_name}
    assert parse_command("get /\\") == {:error, :illegal_file_name}
  end

  test "put: illegal usage" do
    assert parse_command("put a b c d e f") == {:error, {:usage, :put}}
  end

  test "put: can't have more than one space after file path" do
    assert parse_command("put /test       $$$$$") == {:error, {:usage, :put}}
  end

  test "illegal method" do
    assert parse_command("testing") == {:error, {:illegal_method, "testing"}}
    assert parse_command("testing bla bla bla") == {:error, {:illegal_method, "testing"}}
  end

  test "remove_newline_and_match_parts" do
    assert CommandParser.match_space_separated_parts("list /", ["list", "/"]) ==
             {:ok, ["list", "/"]}

    assert CommandParser.match_space_separated_parts("list /     ", ["list", _]) ==
             {:ok, ["list", "/"]}

    assert CommandParser.match_space_separated_parts(
             "put a b c d e f",
             [
               "put",
               _,
               _,
               _,
               _,
               _,
               _
             ]
           ) == {:ok, ["put", "a", "b", "c", "d", "e", "f"]}
  end

  # test "can parse get with revision" do
  #   assert parse_command("get /a 1\n") == {:ok, %CommandParser.Get{path: "/a", revision: 1}}
  #   assert parse_command("get /a r1\n") == {:ok, %CommandParser.Get{path: "/a", revision: 1}}
  #   assert parse_command("get /a 1rrr\n") == {:ok, %CommandParser.Get{path: "/a", revision: 1}}
  # end
end
