defmodule Protohackers.VoraciousCodeStorage.CommandParser do
  require Logger

  @type path :: binary()
  @type result() :: :help | {:list, path()}

  @spec parse(binary()) :: {:ok, result(), binary()} | :incomplete | :error
  def parse(binary)

  def parse(<<"help", rest::binary>>) do
    with {:ok, _, rest} <- split_on_newline(rest) do
      {:ok, :help, rest}
    end
  end

  def parse(<<"list ", rest::binary>>) do
    with {:ok, maybe_directory, rest} <- split_on_newline(rest) do
      if is_directory?(maybe_directory) do
        {:ok, {:list, maybe_directory}, rest}
      else
        :error
      end
    end
  end

  def parse(<<prefix::binary-3, rest::binary>> = all) do
    case String.downcase(prefix, :ascii) do
      "put" ->
        parse("put" <> rest)

      "get" ->
        parse("get" <> rest)

      prefix when prefix in ["lis", "hel"] ->
        if byte_size(rest) > 0 do
          <<command::binary-4, rest::binary>> = all

          case String.downcase(command, :ascii) do
            "list" ->
              parse("list" <> rest)

            "help" ->
              parse("help" <> rest)

            _ ->
              :error
          end
        else
          :incomplete
        end

      _ ->
        :error
    end
  end

  def parse(_), do: :error

  @spec split_on_newline(binary()) :: {:ok, binary(), binary()} | :incomplete
  defp split_on_newline(command) do
    if String.contains?(command, "\n") do
      [command, rest] = String.split(command, "\n", parts: 2)
      {:ok, String.trim_trailing(command), rest}
    else
      :incomplete
    end
  end

  @spec is_directory?(binary()) :: boolean()
  defp is_directory?(value) do
    value =~ ~r'^/[[:alnum:]_\-\./]*$'
  end
end
