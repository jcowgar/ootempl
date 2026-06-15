defmodule Ootempl.FiltersTest do
  use ExUnit.Case, async: false

  alias Ootempl.Filters
  alias Ootempl.Placeholder
  alias Ootempl.Replacement

  doctest Filters

  # Helper: parse one placeholder, resolve its raw value from data, run the
  # filter chain through the built-in registry.
  defp run(text, data) do
    [ph] = Placeholder.detect(text)
    {:ok, raw} = Ootempl.DataAccess.get_raw_value(data, ph.path)
    Filters.apply_chain(raw, ph.filters, Filters.builtins())
  end

  describe "Placeholder.detect/1 filter parsing" do
    test "placeholder without filters has empty filter list" do
      assert [%{filters: []}] = Placeholder.detect("{{name}}")
    end

    test "parses a single filter with no args" do
      assert [%{path: ["name"], filters: [%{name: "upcase", args: []}]}] =
               Placeholder.detect("{{ name | upcase }}")
    end

    test "parses a filter with a quoted string argument" do
      assert [%{filters: [%{name: "date", args: ["%Y-%m-%d"]}]}] =
               Placeholder.detect(~S({{d | date: "%Y-%m-%d"}}))
    end

    test "parses integer and float arguments" do
      assert [%{filters: [%{name: "round", args: [2]}]}] =
               Placeholder.detect("{{n | round: 2}}")

      assert [%{filters: [%{name: "f", args: [1.5]}]}] =
               Placeholder.detect("{{n | f: 1.5}}")
    end

    test "respects quotes so colons and commas inside args are preserved" do
      assert [%{filters: [%{name: "time", args: ["%H:%M:%S"]}]}] =
               Placeholder.detect(~S({{t | time: "%H:%M:%S"}}))

      assert [%{filters: [%{name: "number", args: ["#,##0.00"]}]}] =
               Placeholder.detect(~S({{n | number: "#,##0.00"}}))
    end

    test "parses a chain of filters" do
      assert [%{filters: [%{name: "round", args: [2]}, %{name: "currency", args: ["USD"]}]}] =
               Placeholder.detect(~S({{ total | round: 2 | currency: "USD" }}))
    end

    test "does not match block, conditional, or image markers" do
      assert Placeholder.detect("{{#items}}") == []
      assert Placeholder.detect("{{/items}}") == []
      assert Placeholder.detect("{{image:logo}}") == []
      assert Placeholder.detect("{{if active}}") == []
    end
  end

  describe "date/time filters" do
    test "date with default format" do
      assert run("{{d | date}}", %{"d" => ~D[2026-06-15]}) == {:ok, "2026-06-15"}
    end

    test "date with custom format" do
      assert run(~S({{d | date: "%d %B %Y"}}), %{"d" => ~D[2026-06-15]}) ==
               {:ok, "15 June 2026"}
    end

    test "date accepts an ISO 8601 string" do
      assert run(~S({{d | date: "%Y/%m/%d"}}), %{"d" => "2026-06-15"}) == {:ok, "2026/06/15"}
    end

    test "time with custom format" do
      assert run(~S({{t | time: "%H:%M"}}), %{"t" => ~T[09:05:00]}) == {:ok, "09:05"}
    end

    test "datetime with default format" do
      assert run("{{dt | datetime}}", %{"dt" => ~N[2026-06-15 09:05:30]}) ==
               {:ok, "2026-06-15 09:05:30"}
    end

    test "date on a non-date value returns an error" do
      assert {:error, {:filter_error, "date", :not_a_date}} =
               run("{{d | date}}", %{"d" => 42})
    end
  end

  describe "number filters" do
    test "round to N places" do
      assert run("{{n | round: 2}}", %{"n" => 3.14159}) == {:ok, 3.14}
    end

    test "round with no args truncates to an integer" do
      assert run("{{n | round}}", %{"n" => 3.7}) == {:ok, 4}
    end

    test "number adds thousands separators" do
      assert run("{{n | number}}", %{"n" => 1_234_567.5}) == {:ok, "1,234,567.5"}
    end

    test "number with precision forces decimal places" do
      assert run("{{n | number: 2}}", %{"n" => 1_234_567}) == {:ok, "1,234,567.00"}
    end

    test "currency uses a known symbol and two decimals" do
      assert run(~S({{n | currency: "USD"}}), %{"n" => 1234.5}) == {:ok, "$1,234.50"}
      assert run(~S({{n | currency: "EUR"}}), %{"n" => 99}) == {:ok, "€99.00"}
    end

    test "negative currency places the sign before the symbol" do
      assert run(~S({{n | currency: "USD"}}), %{"n" => -1234.5}) == {:ok, "-$1,234.50"}
    end

    test "currency defaults to a dollar sign" do
      assert run("{{n | currency}}", %{"n" => 5}) == {:ok, "$5.00"}
    end

    test "number on a non-numeric value returns an error" do
      assert {:error, {:filter_error, "number", :not_a_number}} =
               run("{{n | number}}", %{"n" => "abc"})
    end
  end

  describe "string filters" do
    test "upcase / downcase / capitalize / trim" do
      assert run("{{s | upcase}}", %{"s" => "hi"}) == {:ok, "HI"}
      assert run("{{s | downcase}}", %{"s" => "HI"}) == {:ok, "hi"}
      assert run("{{s | capitalize}}", %{"s" => "hello"}) == {:ok, "Hello"}
      assert run("{{s | trim}}", %{"s" => "  x  "}) == {:ok, "x"}
    end

    test "truncate with default ellipsis" do
      assert run("{{s | truncate: 8}}", %{"s" => "hello world"}) == {:ok, "hello..."}
    end

    test "truncate leaves short strings untouched" do
      assert run("{{s | truncate: 50}}", %{"s" => "short"}) == {:ok, "short"}
    end
  end

  describe "default filter" do
    test "substitutes the fallback for nil" do
      assert run(~S({{s | default: "N/A"}}), %{"s" => nil}) == {:ok, "N/A"}
    end

    test "substitutes the fallback for an empty/blank string" do
      assert run(~S({{s | default: "N/A"}}), %{"s" => "   "}) == {:ok, "N/A"}
    end

    test "keeps a present value" do
      assert run(~S({{s | default: "N/A"}}), %{"s" => "x"}) == {:ok, "x"}
    end
  end

  describe "chaining" do
    test "feeds each filter's output into the next" do
      assert run(~S({{p | round: 2 | currency: "USD"}}), %{"p" => "19.999"}) ==
               {:ok, "$20.00"}
    end
  end

  describe "Placeholder.detect/1 — additional parsing cases" do
    test "plain placeholder with surrounding whitespace still matches" do
      assert [%{path: ["name"], filters: []}] = Placeholder.detect("{{ name }}")
    end

    test "single-quoted argument" do
      assert [%{filters: [%{name: "date", args: ["%Y-%m-%d"]}]}] =
               Placeholder.detect("{{d | date: '%Y-%m-%d'}}")
    end

    test "bare-word (unquoted, non-numeric) argument is treated as a string" do
      assert [%{filters: [%{name: "default", args: ["none"]}]}] =
               Placeholder.detect("{{x | default: none}}")
    end

    test "multiple comma-separated arguments" do
      assert [%{filters: [%{name: "truncate", args: [20, "…"]}]}] =
               Placeholder.detect(~S({{s | truncate: 20, "…"}}))
    end

    test "trailing empty filter section yields no filters" do
      assert [%{path: ["name"], filters: []}] = Placeholder.detect("{{ name | }}")
    end

    test "escaped placeholder with a filter is not detected" do
      assert Placeholder.detect(~S(\{{ x | upcase }})) == []
    end

    test "multiple filtered placeholders in one string" do
      assert [
               %{path: ["a"], filters: [%{name: "upcase", args: []}]},
               %{path: ["b"], filters: [%{name: "downcase", args: []}]}
             ] = Placeholder.detect("{{a | upcase}} and {{b | downcase}}")
    end

    test "byte offsets stay correct when a multibyte char precedes a filtered placeholder" do
      # The em-dash is 3 bytes; the filter section is extracted via :binary.part,
      # so a grapheme/byte mismatch would corrupt the captured filter.
      assert [%{original: original, path: ["year"], filters: [%{name: "upcase", args: []}]}] =
               Placeholder.detect("Range 2020—2024 {{year | upcase}} end")

      assert original == "{{year | upcase}}"
    end
  end

  describe "date/time coercion matrix" do
    test "time with default format" do
      assert run("{{t | time}}", %{"t" => ~T[09:05:30]}) == {:ok, "09:05:30"}
    end

    test "datetime with custom format" do
      assert run(~S({{dt | datetime: "%d/%m/%Y %H:%M"}}), %{"dt" => ~N[2026-06-15 09:05:30]}) ==
               {:ok, "15/06/2026 09:05"}
    end

    test "date filter accepts a DateTime struct" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-06-15T09:05:30Z")
      assert run("{{d | date}}", %{"d" => dt}) == {:ok, "2026-06-15"}
    end

    test "date filter falls back to parsing a datetime string" do
      assert run("{{d | date}}", %{"d" => "2026-06-15T09:05:30"}) == {:ok, "2026-06-15"}
    end

    test "time filter accepts a NaiveDateTime" do
      assert run("{{t | time}}", %{"t" => ~N[2026-06-15 09:05:30]}) == {:ok, "09:05:30"}
    end

    test "datetime filter parses an ISO datetime with offset" do
      assert run(~S({{dt | datetime: "%Y-%m-%d %H:%M"}}), %{"dt" => "2026-06-15T09:05:30Z"}) ==
               {:ok, "2026-06-15 09:05"}
    end

    test "time on a non-time value errors" do
      assert {:error, {:filter_error, "time", :not_a_time}} = run("{{t | time}}", %{"t" => 42})
    end

    test "datetime on a non-datetime value errors" do
      assert {:error, {:filter_error, "datetime", :not_a_datetime}} =
               run("{{dt | datetime}}", %{"dt" => 42})
    end
  end

  describe "number filter edge cases" do
    test "round accepts an integer and a numeric string" do
      assert run("{{n | round: 1}}", %{"n" => 3}) == {:ok, 3.0}
      assert run("{{n | round: 1}}", %{"n" => "3.14"}) == {:ok, 3.1}
    end

    test "round clamps negative precision to zero" do
      assert run("{{n | round: -2}}", %{"n" => 3.7}) == {:ok, 4}
    end

    test "number formats a negative value" do
      assert run("{{n | number}}", %{"n" => -1_234.5}) == {:ok, "-1,234.5"}
    end

    test "number with zero precision rounds to a whole number" do
      assert run("{{n | number: 0}}", %{"n" => 1_234.7}) == {:ok, "1,235"}
    end

    test "currency with an unknown code uses the code as a literal prefix" do
      assert run(~S({{n | currency: "XYZ"}}), %{"n" => 5}) == {:ok, "XYZ5.00"}
    end
  end

  describe "string filter edge cases" do
    test "upcase stringifies a non-string value first" do
      assert run("{{n | upcase}}", %{"n" => 42}) == {:ok, "42"}
    end

    test "truncate uses a custom ellipsis" do
      assert run(~S({{s | truncate: 5, "~"}}), %{"s" => "hello world"}) == {:ok, "hell~"}
    end

    test "truncate leaves a string exactly at the limit untouched" do
      assert run("{{s | truncate: 5}}", %{"s" => "hello"}) == {:ok, "hello"}
    end

    test "truncate with a length shorter than the ellipsis yields just the ellipsis" do
      assert run("{{s | truncate: 1}}", %{"s" => "hello"}) == {:ok, "..."}
    end
  end

  describe "default filter edge cases" do
    test "treats false and zero as present values" do
      assert run("{{x | default: 9}}", %{"x" => false}) == {:ok, false}
      assert run("{{x | default: 9}}", %{"x" => 0}) == {:ok, 0}
    end
  end

  describe "filters and nil values" do
    test "a string filter on nil yields an empty string (filters opt out of the nil guard)" do
      assert run("{{x | upcase}}", %{"x" => nil}) == {:ok, ""}
    end

    test "a numeric filter on nil errors" do
      assert {:error, {:filter_error, "number", :not_a_number}} =
               run("{{x | number}}", %{"x" => nil})
    end
  end

  describe "apply_chain/3 errors" do
    test "unknown filter" do
      assert Filters.apply_chain("x", [%{name: "nope", args: []}], Filters.builtins()) ==
               {:error, {:unknown_filter, "nope"}}
    end

    test "an empty filter list returns the value unchanged" do
      assert Filters.apply_chain("x", [], Filters.builtins()) == {:ok, "x"}
    end

    test "a filter returning a non-result tuple is reported as a bad return" do
      registry = %{"bad" => fn _v, _a -> "oops" end}

      assert Filters.apply_chain("x", [%{name: "bad", args: []}], registry) ==
               {:error, {:filter_bad_return, "bad", "oops"}}
    end

    test "the chain halts at the first unknown filter, after running earlier ones" do
      assert Filters.apply_chain(
               "hi",
               [%{name: "upcase", args: []}, %{name: "nope", args: []}],
               Filters.builtins()
             ) == {:error, {:unknown_filter, "nope"}}
    end
  end

  describe "registry resolution and overrides" do
    test "per-call filters override built-ins" do
      custom = %{"upcase" => fn value, _args -> {:ok, "OVERRIDDEN-#{value}"} end}
      registry = Filters.resolve(custom)
      assert {:ok, fun} = Map.fetch(registry, "upcase")
      assert fun.("x", []) == {:ok, "OVERRIDDEN-x"}
    end

    test "filter names are matched case-insensitively" do
      custom = %{"Money" => fn _v, _a -> {:ok, "money"} end}
      registry = Filters.resolve(custom)
      assert Map.has_key?(registry, "money")
    end

    test "application config filters are picked up by default_registry/0" do
      Application.put_env(:ootempl, :filters, %{"shout" => fn v, _ -> {:ok, "#{v}!"} end})
      on_exit(fn -> Application.delete_env(:ootempl, :filters) end)

      registry = Filters.default_registry()
      assert {:ok, fun} = Map.fetch(registry, "shout")
      assert fun.("hey", []) == {:ok, "hey!"}
    end

    test "per-call filters override application config" do
      Application.put_env(:ootempl, :filters, %{"x" => fn _v, _ -> {:ok, "app"} end})
      on_exit(fn -> Application.delete_env(:ootempl, :filters) end)

      registry = Filters.resolve(%{"x" => fn _v, _ -> {:ok, "call"} end})
      assert {:ok, fun} = Map.fetch(registry, "x")
      assert fun.(nil, []) == {:ok, "call"}
    end

    test "filters supplied with atom keys are normalized to string names" do
      registry = Filters.resolve(%{money: fn _v, _ -> {:ok, "€"} end})
      assert {:ok, fun} = Map.fetch(registry, "money")
      assert fun.(nil, []) == {:ok, "€"}
    end

    test "application config can override a built-in filter" do
      Application.put_env(:ootempl, :filters, %{"upcase" => fn _v, _ -> {:ok, "CONFIGGED"} end})
      on_exit(fn -> Application.delete_env(:ootempl, :filters) end)

      registry = Filters.default_registry()
      assert registry["upcase"].("x", []) == {:ok, "CONFIGGED"}
    end
  end

  describe "with_registry/2" do
    test "installs the registry for the current process and restores it after" do
      refute Process.get(:ootempl_active_filters)

      result =
        Filters.with_registry(%{"x" => fn _v, _ -> {:ok, "ran"} end}, fn ->
          Filters.active_registry()["x"].(nil, [])
        end)

      assert result == {:ok, "ran"}
      refute Process.get(:ootempl_active_filters)
    end

    test "restores the previous registry even when the function raises" do
      assert_raise RuntimeError, fn ->
        Filters.with_registry(%{"x" => fn _, _ -> {:ok, 1} end}, fn -> raise "boom" end)
      end

      refute Process.get(:ootempl_active_filters)
    end

    test "nested calls restore the outer registry, not just the default" do
      outer = %{"x" => fn _v, _ -> {:ok, "outer"} end}
      inner = %{"x" => fn _v, _ -> {:ok, "inner"} end}

      Filters.with_registry(outer, fn ->
        assert Filters.active_registry()["x"].(nil, []) == {:ok, "outer"}

        Filters.with_registry(inner, fn ->
          assert Filters.active_registry()["x"].(nil, []) == {:ok, "inner"}
        end)

        # After the inner block exits, the outer registry is restored.
        assert Filters.active_registry()["x"].(nil, []) == {:ok, "outer"}
      end)

      refute Process.get(:ootempl_active_filters)
    end
  end

  describe "Replacement integration" do
    @ns ~S(xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main")

    defp doc(inner) do
      "<w:document #{@ns}>#{inner}</w:document>"
    end

    defp replace(inner, data) do
      {:ok, parsed} = Ootempl.Xml.parse(doc(inner))
      {:ok, replaced} = Replacement.replace_in_document(parsed, data)
      {:ok, serialized} = Ootempl.Xml.serialize(replaced)
      serialized
    end

    test "applies a built-in filter through the full replacement pipeline" do
      inner = ~S(<w:p><w:r><w:t>Total: {{amount | currency: "USD"}}</w:t></w:r></w:p>)
      result = replace(inner, %{"amount" => 1234.5})
      assert result =~ "Total: $1,234.50"
      refute result =~ "{{amount"
    end

    test "reports a filter error through PlaceholderError" do
      {:ok, parsed} = Ootempl.Xml.parse(doc(~S(<w:p><w:r><w:t>{{d | date}}</w:t></w:r></w:p>)))

      assert {:error, %Ootempl.PlaceholderError{placeholders: [%{reason: reason}]}} =
               Replacement.replace_in_document(parsed, %{"d" => 42})

      assert reason == {:filter_error, "date", :not_a_date}
    end

    test "a per-call registry installed via with_registry is used by replacement" do
      inner = ~S(<w:p><w:r><w:t>{{name | shout}}</w:t></w:r></w:p>)
      registry = Filters.resolve(%{"shout" => fn v, _ -> {:ok, String.upcase("#{v}!")} end})

      result =
        Filters.with_registry(registry, fn ->
          {:ok, parsed} = Ootempl.Xml.parse(doc(inner))
          {:ok, replaced} = Replacement.replace_in_document(parsed, %{"name" => "ada"})
          {:ok, serialized} = Ootempl.Xml.serialize(replaced)
          serialized
        end)

      assert result =~ "ADA!"
    end

    test "a filter chain split across runs is normalized and applied" do
      # Word frequently fragments placeholder text across multiple <w:r> runs.
      # Normalization must merge the whole `{{ ... | filter }}` span before
      # replacement, including the part after the pipe.
      inner =
        ~S(<w:p><w:r><w:t>{{ amount </w:t></w:r>) <>
          ~S(<w:r><w:t>| currency: "USD" }}</w:t></w:r></w:p>)

      {:ok, parsed} = Ootempl.Xml.parse(doc(inner))
      normalized = Ootempl.Xml.Normalizer.normalize(parsed)
      {:ok, replaced} = Replacement.replace_in_document(normalized, %{"amount" => 1234.5})
      {:ok, serialized} = Ootempl.Xml.serialize(replaced)

      assert serialized =~ "$1,234.50"
      refute serialized =~ "currency"
    end
  end
end
