# Profiling script using Erlang's :eprof (simpler than :fprof)
#
# This provides function-level timing information using built-in Erlang tools.
#
# Run with: mix run benchmarks/profile_eprof.exs

# Setup output directories
profile_dir = "benchmarks/profiles"
output_dir = "benchmarks/output"
File.mkdir_p!(profile_dir)
File.mkdir_p!(output_dir)

# Helper to generate test data
defmodule EprofHelpers do
  def generate_table_data(num_rows) do
    Enum.map(1..num_rows, fn i ->
      %{
        "id" => Integer.to_string(5000 + i),
        "amount" => Float.to_string(:rand.uniform(1000) + 0.50)
      }
    end)
  end

  def generate_simple_data do
    %{
      "name" => "John Doe",
      "email" => "john.doe@example.com",
      "company" => "Acme Corporation",
      "address" => "123 Main Street",
      "city" => "Springfield",
      "state" => "IL",
      "zip" => "62701",
      "phone" => "(555) 123-4567",
      "date" => "October 7, 2025",
      "invoice_number" => "INV-2025-001234",
      "total" => "1,234.56"
    }
  end
end

IO.puts("\n=== Ootempl :eprof Profiling ===\n")
IO.puts("Running function profiling...")
IO.puts("Results will be saved to: #{profile_dir}/eprof_analysis.txt\n")

# Profile table rendering with 50 rows (most interesting case)
data = %{
  "title" => "Invoice Report",
  "date" => "October 7, 2025",
  "claims" => EprofHelpers.generate_table_data(50),
  "total" => "12,345.67"
}

output = "#{output_dir}/profile_eprof.docx"

# Start profiling
IO.puts("Profiling render operation with 50-row table (10 iterations)...\n")
:eprof.start()

# Start profiling all processes
:eprof.start_profiling([self()])

# Run the operation we want to profile (run 10 times for better data)
Enum.each(1..10, fn _i ->
  Ootempl.render("test/fixtures/table_simple.docx", data, output)
  File.rm!(output)
end)

# Stop profiling and analyze
:eprof.stop_profiling()
:eprof.analyze(:total)

# Get the analysis results
IO.puts("\n\n=== Detailed Analysis ===\n")
:eprof.log(String.to_charlist("#{profile_dir}/eprof_full.txt"))
:eprof.analyze(:total)

# Stop eprof
:eprof.stop()

# Cleanup
File.rm_rf!(output_dir)

IO.puts("\n\n=== Profiling Complete ===\n")
IO.puts("Full analysis saved to: #{profile_dir}/eprof_full.txt")
IO.puts("\nThe analysis shows:")
IO.puts("  - FUNCTION: Module:Function/Arity")
IO.puts("  - CALLS: Number of times the function was called")
IO.puts("  - TIME: Percentage of total time spent")
IO.puts("\nLook for functions with high TIME percentages\n")
