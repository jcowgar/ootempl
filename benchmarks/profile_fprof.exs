# Alternative profiling script using Erlang's built-in :fprof
#
# This provides detailed per-function timing information without requiring
# additional dependencies. Use this for detailed call analysis.
#
# Run with: mix run benchmarks/profile_fprof.exs

# Setup output directories
profile_dir = "benchmarks/profiles"
output_dir = "benchmarks/output"
File.mkdir_p!(profile_dir)
File.mkdir_p!(output_dir)

# Helper to generate test data
defmodule FprofHelpers do
  def generate_table_data(num_rows) do
    Enum.map(1..num_rows, fn i ->
      %{
        "id" => Integer.to_string(5000 + i),
        "amount" => Float.to_string(:rand.uniform(1000) + 0.50)
      }
    end)
  end
end

IO.puts("\n=== Ootempl :fprof Profiling ===\n")
IO.puts("Running detailed function profiling...")
IO.puts("Results will be saved to: #{profile_dir}/fprof_analysis.txt\n")

# Profile table rendering with 50 rows (most interesting case)
data = %{
  "title" => "Invoice Report",
  "date" => "October 7, 2025",
  "claims" => FprofHelpers.generate_table_data(50),
  "total" => "12,345.67"
}

output = "#{output_dir}/profile_fprof.docx"

# Start profiling
:fprof.start()

# Trace the function calls
:fprof.trace([:start, {:procs, :all}])

# Run the operation we want to profile
IO.puts("Profiling render operation with 50-row table...")
Ootempl.render("test/fixtures/table_simple.docx", data, output)

# Stop tracing
:fprof.trace(:stop)

# Analyze the results
IO.puts("Analyzing trace data...")
:fprof.profile()

# Write analysis to file
analysis_file = "#{profile_dir}/fprof_analysis.txt"
:fprof.analyse(dest: String.to_charlist(analysis_file), sort: :own)

# Stop fprof
:fprof.stop()

# Cleanup
File.rm(output)
File.rm_rf!(output_dir)

IO.puts("\n=== Profiling Complete ===\n")
IO.puts("Detailed profiling analysis saved to: #{analysis_file}")
IO.puts("\nThe analysis shows:")
IO.puts("  - CNT: Number of times function was called")
IO.puts("  - ACC: Accumulated time (includes time in called functions)")
IO.puts("  - OWN: Own time (time spent in the function itself)")
IO.puts("\nFunctions are sorted by OWN time (most expensive first)")
IO.puts("\nOpen the file to see which functions are taking the most time:\n")
IO.puts("  open #{analysis_file}\n")

# Also create a summary
IO.puts("Parsing top hotspots...")

case File.read(analysis_file) do
  {:ok, content} ->
    # Extract some key lines for quick summary
    lines =
      content
      |> String.split("\n")
      |> Enum.filter(&String.contains?(&1, "Ootempl"))
      |> Enum.take(20)

    if length(lines) > 0 do
      IO.puts("\nTop Ootempl functions by time spent:\n")
      Enum.each(lines, &IO.puts/1)
    end

  {:error, _} ->
    :ok
end

IO.puts("")
