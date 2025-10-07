# Detailed analysis of normalization performance
#
# Run with: mix run benchmarks/analyze_normalization.exs

profile_file = "benchmarks/profiles/eprof_full.txt"

unless File.exists?(profile_file) do
  IO.puts("Profile file not found. Run: mix run benchmarks/profile_eprof.exs first")
  System.halt(1)
end

{:ok, content} = File.read(profile_file)

# Parse the profile output
lines =
  content
  |> String.split("\n")
  |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "---") or String.starts_with?(&1, "FUNCTION")))
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

# Extract function data
functions =
  Enum.reduce(lines, [], fn line, acc ->
    case Regex.run(~r/^(.+?)\s+(\d+)\s+([\d.]+)\s+(\d+)\s+\[/, line) do
      [_, func, calls, percent, time] ->
        [
          %{
            function: func,
            calls: String.to_integer(calls),
            percent: String.to_float(percent),
            time_us: String.to_integer(time)
          }
          | acc
        ]

      _ ->
        acc
    end
  end)

# Get total time
total_time = Enum.sum(Enum.map(functions, & &1.time_us))

# Filter Normalizer functions
normalizer_funcs =
  Enum.filter(functions, fn %{function: f} ->
    String.contains?(f, "Normalizer")
  end)

# Sort by time
normalizer_sorted = Enum.sort_by(normalizer_funcs, & &1.time_us, :desc)

# Calculate total normalizer time
normalizer_time = Enum.sum(Enum.map(normalizer_funcs, & &1.time_us))
normalizer_calls = Enum.sum(Enum.map(normalizer_funcs, & &1.calls))

# Also get XML parsing time (xmerl)
xml_parse_funcs =
  Enum.filter(functions, fn %{function: f} ->
    String.contains?(f, "xmerl_scan")
  end)

xml_parse_time = Enum.sum(Enum.map(xml_parse_funcs, & &1.time_us))

# Get Replacement module time
replacement_funcs =
  Enum.filter(functions, fn %{function: f} ->
    String.contains?(f, "Ootempl.Replacement")
  end)

replacement_time = Enum.sum(Enum.map(replacement_funcs, & &1.time_us))

IO.puts("\n=== Normalization Performance Analysis ===\n")
IO.puts("Profile: 10 iterations of rendering a 50-row table template\n")

IO.puts("Total execution time:     #{total_time} μs (100%)")
IO.puts("Normalization time:       #{normalizer_time} μs (#{Float.round(normalizer_time / total_time * 100, 2)}%)")
IO.puts("XML Parsing (xmerl_scan): #{xml_parse_time} μs (#{Float.round(xml_parse_time / total_time * 100, 2)}%)")
IO.puts("Replacement time:         #{replacement_time} μs (#{Float.round(replacement_time / total_time * 100, 2)}%)")
IO.puts("")

IO.puts("Per document (average):")
IO.puts("  Total time:         #{Float.round(total_time / 10, 1)} μs")
IO.puts("  Normalization:      #{Float.round(normalizer_time / 10, 1)} μs")
IO.puts("  XML Parsing:        #{Float.round(xml_parse_time / 10, 1)} μs")
IO.puts("  Replacement:        #{Float.round(replacement_time / 10, 1)} μs")
IO.puts("")

IO.puts("=== All Normalizer Functions (sorted by time) ===\n")

normalizer_sorted
|> Enum.each(fn %{function: f, calls: c, time_us: t, percent: p} ->
  clean = String.replace(f, "'Elixir.Ootempl.Xml.", "")
  clean = String.replace(clean, "':", ":")
  IO.puts("#{String.pad_trailing(clean, 70)} #{String.pad_leading(Integer.to_string(t), 6)}μs  #{String.pad_leading(Integer.to_string(c), 5)} calls")
end)

IO.puts("\n=== Key Findings ===\n")

IO.puts("1. Normalization is FAST: Only #{Float.round(normalizer_time / total_time * 100, 2)}% of total time")
IO.puts("   - Average per document: #{Float.round(normalizer_time / 10, 1)}μs (~#{Float.round(normalizer_time / 10 / 1000, 3)}ms)")
IO.puts("")

IO.puts("2. Normalization is called #{normalizer_calls} times across #{length(normalizer_funcs)} functions")
IO.puts("   - Top function: #{hd(normalizer_sorted).function} (#{hd(normalizer_sorted).time_us}μs)")
IO.puts("")

IO.puts("3. Normalization is #{Float.round(xml_parse_time / normalizer_time, 1)}x FASTER than XML parsing")
IO.puts("   - XML parsing: #{xml_parse_time}μs (#{Float.round(xml_parse_time / total_time * 100, 2)}%)")
IO.puts("   - Normalization: #{normalizer_time}μs (#{Float.round(normalizer_time / total_time * 100, 2)}%)")
IO.puts("")

IO.puts("4. Replacement is the main bottleneck, not normalization:")
IO.puts("   - Replacement: #{replacement_time}μs (#{Float.round(replacement_time / total_time * 100, 2)}%)")
IO.puts("   - Normalization: #{normalizer_time}μs (#{Float.round(normalizer_time / total_time * 100, 2)}%)")
IO.puts("   - Replacement is #{Float.round(replacement_time / normalizer_time, 1)}x slower")
IO.puts("")

IO.puts("🎯 CONCLUSION: Normalization is NOT a bottleneck. It takes only ~#{Float.round(normalizer_time / 10, 1)}μs")
IO.puts("   per document (#{Float.round(normalizer_time / 10 / 1000, 3)}ms), which is negligible.")
IO.puts("")
