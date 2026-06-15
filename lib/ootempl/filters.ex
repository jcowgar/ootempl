defmodule Ootempl.Filters do
  @moduledoc """
  Formatting filters applied to placeholder values.

  Filters let template authors control how a value is rendered without bloating
  the placeholder text. They are written Jinja/Liquid style after the variable,
  separated by `|`:

      {{ invoice.date | date: "%d %B %Y" }}
      {{ total | round: 2 | currency: "USD" }}
      {{ name | upcase }}
      {{ middle_name | default: "—" }}

  ## Filter functions

  A filter is a 2-arity function `(value, args) -> {:ok, term} | {:error, reason}`
  where `value` is the raw, un-stringified value resolved from the data (so a
  `%Date{}` arrives as a `%Date{}`, not a string) and `args` is the list of
  parsed arguments. Returning a term (not necessarily a string) lets filters
  chain: the output of one filter becomes the input of the next, and the final
  value is converted to a string for the document.

  On `{:error, reason}` the chain halts and the failure is reported through the
  usual `Ootempl.PlaceholderError` batch reporting.

  ## Nil values

  A bare placeholder whose value is `nil` is reported as a missing-value error.
  Once a filter is applied, the filter decides how to handle `nil`: `default`
  substitutes a fallback, the numeric/date filters raise a filter error, and
  the string filters (`upcase`, etc.) treat `nil` as an empty string. Use
  `default` when a value may legitimately be absent.

  ## Registering and overriding filters

  Filters are resolved from three layers, each overriding the previous:

  1. The built-ins returned by `builtins/0`.
  2. Application config: `config :ootempl, filters: %{"money" => &MyApp.money/2}`.
  3. A per-call `:filters` option passed to `Ootempl.render/4`.

  Filter names are matched case-insensitively. Registering a filter under the
  name of a built-in overrides that built-in.

  ## Built-in filters

  | Name | Example | Notes |
  | --- | --- | --- |
  | `date` | `date: "%Y-%m-%d"` | `Calendar.strftime` on a Date/DateTime/ISO string |
  | `time` | `time: "%H:%M"` | Time/DateTime/ISO string |
  | `datetime` | `datetime: "%Y-%m-%d %H:%M"` | NaiveDateTime/DateTime/ISO string |
  | `round` | `round: 2` | Rounds a number to N places (default 0) |
  | `number` | `number: 2` | Thousands separators, optional decimal places |
  | `currency` | `currency: "USD"` | Currency symbol + grouped number (default `$`) |
  | `upcase` / `downcase` / `capitalize` | `upcase` | String case |
  | `trim` | `trim` | Strips surrounding whitespace |
  | `truncate` | `truncate: 20` | Truncates with an ellipsis (default length 50) |
  | `default` | `default: "N/A"` | Fallback when the value is nil or empty |
  """

  alias Ootempl.Placeholder

  @type registry :: %{optional(String.t()) => (term(), [term()] -> {:ok, term()} | {:error, term()})}

  @currency_symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "CAD" => "$",
    "AUD" => "$"
  }

  @doc """
  Returns the built-in filter registry, keyed by lowercased filter name.
  """
  @spec builtins() :: registry()
  def builtins do
    %{
      "date" => &filter_date/2,
      "time" => &filter_time/2,
      "datetime" => &filter_datetime/2,
      "round" => &filter_round/2,
      "number" => &filter_number/2,
      "currency" => &filter_currency/2,
      "upcase" => &filter_upcase/2,
      "downcase" => &filter_downcase/2,
      "capitalize" => &filter_capitalize/2,
      "trim" => &filter_trim/2,
      "truncate" => &filter_truncate/2,
      "default" => &filter_default/2
    }
  end

  @doc """
  Builds the effective filter registry by layering built-ins, application
  config, and a per-call override map (highest precedence). All keys are
  normalized to lowercase strings.

  ## Parameters

    - `call_filters` - Optional map of per-call filters (string or atom keys)
  """
  @spec resolve(map() | nil) :: registry()
  def resolve(call_filters \\ nil) do
    app_filters = Application.get_env(:ootempl, :filters, %{})

    builtins()
    |> Map.merge(normalize_keys(app_filters))
    |> Map.merge(normalize_keys(call_filters || %{}))
  end

  @doc """
  The default registry (built-ins + application config) with no per-call
  overrides. Used as the default when callers don't supply filters.
  """
  @spec default_registry() :: registry()
  def default_registry, do: resolve(nil)

  @active_registry_key :ootempl_active_filters

  @doc """
  Runs `fun` with `registry` installed as the active filter registry for the
  current process, restoring the previous value afterward.

  A render runs synchronously in a single process, so this lets the whole
  pipeline (including deeply-nested table-row replacement) pick up a per-call
  registry via `active_registry/0` without threading it through every
  function. The previous value is always restored, even if `fun` raises.
  """
  @spec with_registry(registry(), (-> result)) :: result when result: term()
  def with_registry(registry, fun) when is_map(registry) and is_function(fun, 0) do
    previous = Process.get(@active_registry_key)
    Process.put(@active_registry_key, registry)

    try do
      fun.()
    after
      case previous do
        nil -> Process.delete(@active_registry_key)
        prev -> Process.put(@active_registry_key, prev)
      end
    end
  end

  @doc """
  Returns the filter registry active for the current process, set by
  `with_registry/2`, or `default_registry/0` when none is active.
  """
  @spec active_registry() :: registry()
  def active_registry do
    Process.get(@active_registry_key) || default_registry()
  end

  @spec normalize_keys(map()) :: registry()
  defp normalize_keys(filters) when is_map(filters) do
    Map.new(filters, fn {name, fun} -> {name |> to_string() |> String.downcase(), fun} end)
  end

  @doc """
  Applies a chain of filters to a value using the given registry.

  Returns `{:ok, value}` with the transformed value, or `{:error, reason}` on
  the first failure (unknown filter or a filter returning an error).

  ## Parameters

    - `value` - The raw value to transform
    - `filters` - List of `%{name:, args:}` filters from `Ootempl.Placeholder`
    - `registry` - Map of filter name to filter function
  """
  @spec apply_chain(term(), [Placeholder.filter()], registry()) ::
          {:ok, term()} | {:error, term()}
  def apply_chain(value, filters, registry) do
    Enum.reduce_while(filters, {:ok, value}, fn filter, {:ok, acc} ->
      case apply_filter(acc, filter, registry) do
        {:ok, _new} = ok -> {:cont, ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @spec apply_filter(term(), Placeholder.filter(), registry()) :: {:ok, term()} | {:error, term()}
  defp apply_filter(value, %{name: name, args: args}, registry) do
    case Map.fetch(registry, String.downcase(name)) do
      {:ok, fun} -> run_filter(fun, value, args, name)
      :error -> {:error, {:unknown_filter, name}}
    end
  end

  @spec run_filter((term(), [term()] -> term()), term(), [term()], String.t()) ::
          {:ok, term()} | {:error, term()}
  defp run_filter(fun, value, args, name) do
    case fun.(value, args) do
      {:ok, _new} = ok -> ok
      {:error, reason} -> {:error, {:filter_error, name, reason}}
      other -> {:error, {:filter_bad_return, name, other}}
    end
  end

  # ── Date / time filters ──────────────────────────────────────────────────

  defp filter_date(value, args) do
    format = Enum.at(args, 0, "%Y-%m-%d")

    with {:ok, date} <- to_date(value) do
      {:ok, Calendar.strftime(date, format)}
    end
  end

  defp filter_time(value, args) do
    format = Enum.at(args, 0, "%H:%M:%S")

    with {:ok, time} <- to_time(value) do
      {:ok, Calendar.strftime(time, format)}
    end
  end

  defp filter_datetime(value, args) do
    format = Enum.at(args, 0, "%Y-%m-%d %H:%M:%S")

    with {:ok, dt} <- to_datetime(value) do
      {:ok, Calendar.strftime(dt, format)}
    end
  end

  defp to_date(%Date{} = d), do: {:ok, d}
  defp to_date(%DateTime{} = d), do: {:ok, d}
  defp to_date(%NaiveDateTime{} = d), do: {:ok, d}

  defp to_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, d} -> {:ok, d}
      _ -> to_datetime(value)
    end
  end

  defp to_date(_), do: {:error, :not_a_date}

  defp to_time(%Time{} = t), do: {:ok, t}
  defp to_time(%DateTime{} = d), do: {:ok, d}
  defp to_time(%NaiveDateTime{} = d), do: {:ok, d}

  defp to_time(value) when is_binary(value) do
    case Time.from_iso8601(value) do
      {:ok, t} -> {:ok, t}
      _ -> to_datetime(value)
    end
  end

  defp to_time(_), do: {:error, :not_a_time}

  defp to_datetime(%DateTime{} = d), do: {:ok, d}
  defp to_datetime(%NaiveDateTime{} = d), do: {:ok, d}

  defp to_datetime(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, dt} ->
        {:ok, dt}

      _ ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _offset} -> {:ok, dt}
          _ -> {:error, :not_a_datetime}
        end
    end
  end

  defp to_datetime(_), do: {:error, :not_a_datetime}

  # ── Number filters ───────────────────────────────────────────────────────

  defp filter_round(value, args) do
    precision = max(Enum.at(args, 0, 0), 0)

    with {:ok, number} <- to_float(value) do
      rounded = Float.round(number, precision)
      {:ok, if(precision == 0, do: trunc(rounded), else: rounded)}
    end
  end

  defp filter_number(value, args) do
    with {:ok, number} <- to_float(value) do
      {:ok, format_number(number, Enum.at(args, 0))}
    end
  end

  defp filter_currency(value, args) do
    symbol = currency_symbol(Enum.at(args, 0))

    with {:ok, number} <- to_float(value) do
      sign = if number < 0, do: "-", else: ""
      {:ok, sign <> symbol <> format_number(abs(number), 2)}
    end
  end

  defp currency_symbol(nil), do: "$"

  defp currency_symbol(code) when is_binary(code) do
    Map.get(@currency_symbols, String.upcase(code), code)
  end

  defp currency_symbol(other), do: to_string(other)

  defp to_float(value) when is_integer(value), do: {:ok, value * 1.0}
  defp to_float(value) when is_float(value), do: {:ok, value}

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {f, ""} -> {:ok, f}
      _ -> {:error, :not_a_number}
    end
  end

  defp to_float(_), do: {:error, :not_a_number}

  # Formats a number with thousands separators. When `precision` is nil the
  # decimal part is preserved as-is (dropping a trailing ".0"); otherwise the
  # value is rounded to `precision` decimal places.
  defp format_number(number, precision) do
    sign = if number < 0, do: "-", else: ""
    {int_part, frac_part} = split_number(abs(number), precision)
    grouped = group_thousands(int_part)
    if frac_part == "", do: sign <> grouped, else: sign <> grouped <> "." <> frac_part
  end

  defp split_number(number, nil) do
    case number |> :erlang.float_to_binary([:short]) |> String.split(".") do
      [int, "0"] -> {int, ""}
      [int, frac] -> {int, frac}
      [int] -> {int, ""}
    end
  end

  defp split_number(number, precision) when is_integer(precision) and precision > 0 do
    [int, frac] =
      number
      |> :erlang.float_to_binary([{:decimals, precision}])
      |> String.split(".")

    {int, frac}
  end

  defp split_number(number, _precision) do
    {number |> Float.round() |> trunc() |> Integer.to_string(), ""}
  end

  defp group_thousands(digits) do
    digits
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  # ── String filters ─────────────────────────────────────────────────────────

  defp filter_upcase(value, _args), do: {:ok, value |> to_string() |> String.upcase()}
  defp filter_downcase(value, _args), do: {:ok, value |> to_string() |> String.downcase()}
  defp filter_capitalize(value, _args), do: {:ok, value |> to_string() |> String.capitalize()}
  defp filter_trim(value, _args), do: {:ok, value |> to_string() |> String.trim()}

  defp filter_truncate(value, args) do
    length = Enum.at(args, 0, 50)
    ellipsis = Enum.at(args, 1, "...")
    string = to_string(value)

    if String.length(string) <= length do
      {:ok, string}
    else
      keep = max(length - String.length(ellipsis), 0)
      {:ok, String.slice(string, 0, keep) <> ellipsis}
    end
  end

  # ── Fallback filter ─────────────────────────────────────────────────────────

  defp filter_default(value, args) do
    fallback = Enum.at(args, 0, "")

    if blank?(value), do: {:ok, fallback}, else: {:ok, value}
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: false
end
