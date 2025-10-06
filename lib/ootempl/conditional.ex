defmodule Ootempl.Conditional do
  @moduledoc """
  Detects and parses conditional markers in text for conditional section processing.

  Conditional markers allow showing or hiding document sections based on data conditions.
  Markers follow the syntax:
  - `@if:variable@` - Start of conditional section
  - `@endif@` - End of conditional section

  Markers are case-insensitive and support nested data paths using dot notation.

  ## Examples

      iex> Ootempl.Conditional.detect_conditionals("Hello @if:name@ world @endif@")
      [
        %{type: :if, condition: "name", path: ["name"], position: 6},
        %{type: :endif, condition: nil, path: nil, position: 22}
      ]

      iex> Ootempl.Conditional.detect_conditionals("@if:customer.active@ content @endif@")
      [
        %{type: :if, condition: "customer.active", path: ["customer", "active"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 29}
      ]
  """

  @type conditional :: %{
          type: :if | :endif,
          condition: String.t() | nil,
          path: [String.t()] | nil,
          position: integer()
        }

  @if_pattern ~r/@if:([a-zA-Z_][a-zA-Z0-9_.]*)@/i
  @endif_pattern ~r/@endif@/i

  @doc """
  Detects all conditional markers in the given text.

  Returns a list of conditional markers in order of appearance with their positions.

  ## Parameters

  - `text` - The text to scan for conditional markers

  ## Returns

  A list of conditional maps, each containing:
  - `:type` - Either `:if` or `:endif`
  - `:condition` - The condition variable (only for `:if` markers)
  - `:path` - Parsed path segments (only for `:if` markers)
  - `:position` - Character position in the text

  ## Examples

      iex> Ootempl.Conditional.detect_conditionals("@if:active@content@endif@")
      [
        %{type: :if, condition: "active", path: ["active"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 18}
      ]

      iex> Ootempl.Conditional.detect_conditionals("no markers here")
      []
  """
  @spec detect_conditionals(String.t()) :: [conditional()]
  def detect_conditionals(text) when is_binary(text) do
    if_markers = find_if_markers(text)
    endif_markers = find_endif_markers(text)

    (if_markers ++ endif_markers)
    |> Enum.sort_by(& &1.position)
  end

  @doc """
  Parses a condition string to extract the variable path.

  Supports dot notation for nested data paths.

  ## Parameters

  - `condition` - The condition variable string (e.g., "customer.active")

  ## Returns

  A list of path segments.

  ## Examples

      iex> Ootempl.Conditional.parse_condition("active")
      ["active"]

      iex> Ootempl.Conditional.parse_condition("customer.active")
      ["customer", "active"]

      iex> Ootempl.Conditional.parse_condition("user.profile.name")
      ["user", "profile", "name"]
  """
  @spec parse_condition(String.t()) :: [String.t()]
  def parse_condition(condition) when is_binary(condition) do
    String.split(condition, ".")
  end

  @doc """
  Validates that all conditional markers are properly paired.

  Ensures each `@if@` has a corresponding `@endif@` and detects orphaned markers.

  ## Parameters

  - `conditionals` - List of conditional markers from `detect_conditionals/1`

  ## Returns

  - `:ok` if all markers are properly paired
  - `{:error, reason}` if validation fails

  ## Examples

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :if, condition: "name", path: ["name"], position: 0},
      ...>   %{type: :endif, condition: nil, path: nil, position: 10}
      ...> ])
      :ok

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :if, condition: "name", path: ["name"], position: 0}
      ...> ])
      {:error, "Unmatched @if:name@ at position 0"}

      iex> Ootempl.Conditional.validate_pairs([
      ...>   %{type: :endif, condition: nil, path: nil, position: 0}
      ...> ])
      {:error, "Orphan @endif@ at position 0 (no matching @if@)"}
  """
  @spec validate_pairs([conditional()]) :: :ok | {:error, String.t()}
  def validate_pairs(conditionals) when is_list(conditionals) do
    validate_pairs_recursive(conditionals, [])
  end

  # Private helper functions

  @spec find_if_markers(String.t()) :: [conditional()]
  defp find_if_markers(text) do
    @if_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}, {cond_start, cond_length}] ->
      condition = String.slice(text, cond_start, cond_length)
      path = parse_condition(condition)

      %{
        type: :if,
        condition: condition,
        path: path,
        position: position
      }
    end)
  end

  @spec find_endif_markers(String.t()) :: [conditional()]
  defp find_endif_markers(text) do
    @endif_pattern
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{position, _length}] ->
      %{
        type: :endif,
        condition: nil,
        path: nil,
        position: position
      }
    end)
  end

  @spec validate_pairs_recursive([conditional()], [conditional()]) ::
          :ok | {:error, String.t()}
  defp validate_pairs_recursive([], []), do: :ok

  defp validate_pairs_recursive([], [unclosed | _]) do
    {:error, "Unmatched @if:#{unclosed.condition}@ at position #{unclosed.position}"}
  end

  defp validate_pairs_recursive([%{type: :if} = marker | rest], stack) do
    validate_pairs_recursive(rest, [marker | stack])
  end

  defp validate_pairs_recursive([%{type: :endif} = marker | _rest], []) do
    {:error, "Orphan @endif@ at position #{marker.position} (no matching @if@)"}
  end

  defp validate_pairs_recursive([%{type: :endif} | rest], [_if_marker | stack]) do
    validate_pairs_recursive(rest, stack)
  end
end
