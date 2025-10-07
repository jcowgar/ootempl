# Analyzes profiling output to find performance bottlenecks
#
# Run with: mix run benchmarks/analyze_profile.exs

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

# Sort by time (descending)
sorted_by_time = Enum.sort_by(functions, & &1.time_us, :desc)

# Filter Ootempl functions
ootempl_funcs =
  Enum.filter(sorted_by_time, fn %{function: f} ->
    String.contains?(f, "Elixir.Ootempl")
  end)

# Filter xmerl/XML functions
xml_funcs =
  Enum.filter(sorted_by_time, fn %{function: f} ->
    String.contains?(f, ["xmerl", "xml", "Xml"])
  end)

# Filter ZIP functions
zip_funcs =
  Enum.filter(sorted_by_time, fn %{function: f} ->
    String.contains?(f, ["zip", "zlib"])
  end)

# Filter file IO functions
io_funcs =
  Enum.filter(sorted_by_time, fn %{function: f} ->
    String.contains?(f, ["file", "File", "prim_file", "io"])
  end)

IO.puts("\n=== Performance Analysis Summary ===\n")

IO.puts("Total functions profiled: #{length(functions)}")
IO.puts("Total time: #{Enum.sum(Enum.map(functions, & &1.time_us))} microseconds")
IO.puts("Ootempl functions: #{length(ootempl_funcs)}")
IO.puts("")

# Show top functions overall
IO.puts("\n=== Top 20 Functions by Time (all) ===\n")

sorted_by_time
|> Enum.take(20)
|> Enum.each(fn %{function: f, calls: c, time_us: t, percent: p} ->
  IO.puts("#{String.pad_trailing(f, 70)} #{String.pad_leading(Integer.to_string(t), 8)}μs (#{p}%)  #{c} calls")
end)

# Show top Ootempl functions
IO.puts("\n\n=== Top 30 Ootempl Functions by Time ===\n")

ootempl_funcs
|> Enum.take(30)
|> Enum.each(fn %{function: f, calls: c, time_us: t} ->
  # Clean up function name
  clean_name = String.replace(f, "'Elixir.Ootempl", "Ootempl")
  clean_name = String.replace(clean_name, "':", ":")

  IO.puts("#{String.pad_trailing(clean_name, 80)} #{String.pad_leading(Integer.to_string(t), 6)}μs  #{c} calls")
end)

# Show category summaries
IO.puts("\n\n=== Time by Category ===\n")

ootempl_time = Enum.sum(Enum.map(ootempl_funcs, & &1.time_us))
xml_time = Enum.sum(Enum.map(xml_funcs, & &1.time_us))
zip_time = Enum.sum(Enum.map(zip_funcs, & &1.time_us))
io_time = Enum.sum(Enum.map(io_funcs, & &1.time_us))
total_time = Enum.sum(Enum.map(functions, & &1.time_us))

IO.puts("Ootempl functions:    #{String.pad_leading(Integer.to_string(ootempl_time), 8)}μs  (#{Float.round(ootempl_time / total_time * 100, 2)}%)")
IO.puts("XML/xmerl functions:  #{String.pad_leading(Integer.to_string(xml_time), 8)}μs  (#{Float.round(xml_time / total_time * 100, 2)}%)")
IO.puts("ZIP/compression:      #{String.pad_leading(Integer.to_string(zip_time), 8)}μs  (#{Float.round(zip_time / total_time * 100, 2)}%)")
IO.puts("File I/O:             #{String.pad_leading(Integer.to_string(io_time), 8)}μs  (#{Float.round(io_time / total_time * 100, 2)}%)")
IO.puts("Total:                #{String.pad_leading(Integer.to_string(total_time), 8)}μs")

IO.puts("\n\n=== Key Insights ===\n")

# Group Ootempl functions by module
by_module =
  ootempl_funcs
  |> Enum.group_by(fn %{function: f} ->
    case Regex.run(~r/'Elixir\.Ootempl\.(\w+)'/, f) do
      [_, module] -> module
      _ -> "Core"
    end
  end)
  |> Enum.map(fn {mod, funcs} ->
    {mod, Enum.sum(Enum.map(funcs, & &1.time_us))}
  end)
  |> Enum.sort_by(fn {_mod, time} -> time end, :desc)

IO.puts("Time by Ootempl module:")
Enum.each(by_module, fn {mod, time} ->
  IO.puts("  #{String.pad_trailing(mod, 25)} #{String.pad_leading(Integer.to_string(time), 8)}μs")
end)

IO.puts("\n")
