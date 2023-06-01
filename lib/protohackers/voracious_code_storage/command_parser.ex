defmodule Protohackers.VoraciousCodeStorage.CommandParser do
  require Logger

  defmacro match_space_separated_parts(data, pattern) do
    quote do
      space_split_list = split_command_parts(unquote(data))

      case space_split_list do
        unquote(pattern) = ret -> {:ok, ret}
        _ -> {:error, :pattern_match_failed}
      end
    end
  end

  defp split_newline(data) do
    case String.split(data, "\n", parts: 2) do
      [_ | []] -> {:error, :no_newline}
      [data | [rest]] -> {:ok, data, rest}
      _ -> {:error, :no_newline}
    end
  end

  def split_command_parts(data) do
    data |> String.trim_trailing() |> String.split(" ")
  end

  defmodule List do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
    end
  end

  defmodule Get do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
      field(:revision, integer() | :latest, enforce: true)
    end
  end

  defmodule Put do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
      field(:length, integer(), enforce: true)
    end
  end

  @type path :: binary()
  @type error() :: {:error, :invalid_path | :invalid_length | {:illegal_method, String.t()}}
  @type result() :: :help | List.t() | Get.t() | Put.t()

  def parse(data) do
    with {:ok, data, rest} <- split_newline(data) do
      case split_command_parts(data) |> Elixir.List.first(nil) do
        nil ->
          {:error, {:illegal_method, ""}}

        cmd ->
          cmd = String.downcase(cmd)
          rest_of_data = String.slice(data, String.length(cmd)..-1)

          with {:ok, result} <- parse_command(cmd <> rest_of_data) do
            {{:ok, result}, rest}
          else
            {:error, {:illegal_method, _}} = err -> err
            err -> {err, rest}
          end
      end
    end
  end

  def parse_command(<<"help", _rest::binary>>) do
    {:ok, :help}
  end

  def parse_command(<<"list", _rest::binary>> = data) do
    with {:ok, ["list", dir_path]} <- match_space_separated_parts(data, ["list", _]),
         true <- is_path?(dir_path) do
      {:ok, %List{path: dir_path}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :list}}
      false -> {:error, :illegal_dir_name}
    end
  end

  def parse_command(<<"get", _rest::binary>> = data) do
    match_result =
      case split_command_parts(data) do
        ["get", file_path] ->
          {:ok, file_path, :latest}

        ["get", file_path, maybe_revision] ->
          maybe_revision =
            if String.starts_with?(maybe_revision, "r") do
              String.slice(maybe_revision, 1..-1)
            else
              maybe_revision
            end

          case String.match?(maybe_revision, ~r/^[[:digit:]]+/) do
            true ->
              %{"revision" => revision} =
                Regex.named_captures(~r/^(?<revision>[[:digit:]]+)/, maybe_revision)

              {:ok, file_path, String.to_integer(revision)}

            false ->
              {:error, :invalid_revision}
          end

        _ ->
          {:error, {:usage, :get}}
      end

    with {:ok, file_path, revision} <- match_result,
         true <- is_path?(file_path),
         true <- !String.ends_with?(file_path, "/") do
      {:ok, %Get{path: file_path, revision: revision}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :get}}
      false -> {:error, :illegal_file_name}
      err -> err
    end
  end

  def parse_command(<<"put", _rest::binary>> = data) do
    with {:ok, ["put", path, length]} <- match_space_separated_parts(data, ["put", _, _]),
         true <- is_path?(path),
         true <- !String.ends_with?(path, "/"),
         {:ok, valid_length} <-
           parse_valid_integer(length) do
      {:ok, %Put{path: path, length: valid_length}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :put}}
      false -> {:error, :illegal_file_name}
      {:error, :invalid_length} = err -> err
    end
  end

  def parse_command(data) do
    {:error, {:illegal_method, data |> String.split(" ") |> Elixir.List.first()}}
  end

  defp parse_valid_integer(maybe_length) do
    cond do
      String.match?(maybe_length, ~r/^[[:digit:]]+/) ->
        %{"length" => length} = Regex.named_captures(~r/^(?<length>[[:digit:]]+)/, maybe_length)
        {:ok, String.to_integer(length)}

      String.match?(maybe_length, ~r/^[^[:space:]].*/) ->
        {:ok, 0}

      true ->
        {:error, :invalid_length}
    end
  end

  @spec is_path?(binary()) :: boolean()
  defp is_path?(value) do
    value =~ ~r'^/[[:alnum:]_\-\./]*$'
  end
end

# PUT /f=J}5 100\n
