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
      assert parse("#{unquote(input)}\n") == {:ok, :help, ""}
    end
  end

  @commands_with_path [{:list, CommandParser.List}, {:get, CommandParser.Get}]
  @command_with_path_success_cases [
    {"/", "/", "can parse root"},
    {"/bla.txt", "/bla.txt", "can parse file in root"},
    {"/bla-testing_new.txt", "/bla-testing_new.txt", "can parse file with hyphen"},
    {"/.", "/.", "can parse /."},
    {"/     ", "/", "can parse root with trailing whitespace"}
  ]

  for {command, struct_name} <- @commands_with_path,
      {input, expected, case_name} <- @command_with_path_success_cases do
    test "#{Atom.to_string(command)}: #{case_name}" do
      assert parse("#{Atom.to_string(unquote(command))} #{unquote(input)}\n") ==
               {:ok, %unquote(struct_name){path: unquote(expected)}, ""}
    end
  end

  @put_success_cases [
    {"/bla.txt 5\nhello", {"/bla.txt", "hello"}, "can parse put"},
    {"/test 2b\na\n", {"/test", "a\n"}, "ignore characters after length but before newline"},
    {"/test bla\n", {"/test", ""}, "(1): non-numeric length is parsed as 0"},
    {"/test _\n", {"/test", ""}, "(2): non-numeric length is parsed as 0"}
  ]

  for {input, {path, data}, case_name} <- @put_success_cases do
    test case_name do
      assert parse("put #{unquote(input)}") ==
               {:ok, %CommandParser.Put{path: unquote(path), data: unquote(data)}, ""}
    end
  end

  test "can't have more than one space after file path" do
    assert parse("put /test       $$$$$\n") == {:error, :invalid_length}
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
      assert parse(unquote(input)) == :incomplete
    end
  end
end
