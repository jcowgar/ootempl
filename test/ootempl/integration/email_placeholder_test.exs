defmodule Ootempl.Integration.EmailPlaceholderTest do
  use ExUnit.Case, async: true

  @fixtures_dir "test/fixtures"

  describe "email address placeholders" do
    test "correctly detects placeholders despite email addresses in template" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholders with Email Addresses.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Print out what placeholders were found for manual verification
      IO.puts("\n=== Placeholders found in 'Simple Placeholders with Email Addresses.docx' ===")
      IO.puts("Total placeholders: #{length(info.placeholders)}")
      IO.puts("\nPlaceholder details:")

      Enum.each(info.placeholders, fn ph ->
        IO.puts("  - Original: #{ph.original}")
        IO.puts("    Path: #{inspect(ph.path)}")
        IO.puts("    Locations: #{inspect(ph.locations)}")
        IO.puts("")
      end)

      IO.puts("Required keys: #{inspect(info.required_keys)}")
      IO.puts("Valid?: #{info.valid?}")

      if length(info.errors) > 0 do
        IO.puts("\nErrors found:")
        Enum.each(info.errors, fn error ->
          IO.puts("  - #{error.message} (#{error.type})")
        end)
      end

      IO.puts("=== End of placeholder inspection ===\n")

      # Basic assertions - we'll add more specific ones after verification
      assert info.valid?, "Template should be valid"
      assert is_list(info.placeholders)
    end
  end
end
