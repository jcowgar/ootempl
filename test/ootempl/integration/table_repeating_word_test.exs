defmodule Ootempl.Integration.TableRepeatingWordTest do
  @moduledoc """
  Integration tests for the "Table Repeating Rows from Word.docx" template.

  This template was created directly in Microsoft Word and contains:
  - Simple variable replacement (@person.first_name@)
  - Table with repeating rows (@people.first_name@, @people.last_name@, @people.age@)
  - Static column (@client@)
  - Summary row with calculated field (@average_age@)
  """

  use ExUnit.Case

  import Ootempl.Xml

  @template_path "test/fixtures/Table Repeating Rows from Word.docx"
  @output_path "test/fixtures/table_repeating_word_output.docx"
  @manual_output_path "test/fixtures/table_repeating_word_manual.docx"

  setup do
    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  describe "table with repeating rows from Word" do
    test "renders template with multiple people in table" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "John"},
        "client" => "Acme Corp",
        "people" => [
          %{"first_name" => "Alice", "last_name" => "Smith", "age" => "28"},
          %{"first_name" => "Bob", "last_name" => "Jones", "age" => "35"},
          %{"first_name" => "Carol", "last_name" => "Davis", "age" => "42"}
        ],
        "average_age" => "35"
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok
      assert File.exists?(@output_path)

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Verify opening text
      assert output_xml =~ "John"

      # Verify client appears (static column)
      assert output_xml =~ "Acme Corp"

      # Verify all people appear in table
      assert output_xml =~ "Alice"
      assert output_xml =~ "Smith"
      assert output_xml =~ "28"

      assert output_xml =~ "Bob"
      assert output_xml =~ "Jones"
      assert output_xml =~ "35"

      assert output_xml =~ "Carol"
      assert output_xml =~ "Davis"
      assert output_xml =~ "42"

      # Verify average age
      assert output_xml =~ "35"

      # Verify placeholders were replaced
      refute output_xml =~ "@person.first_name@"
      refute output_xml =~ "@client@"
      refute output_xml =~ "@people.first_name@"
      refute output_xml =~ "@people.last_name@"
      refute output_xml =~ "@people.age@"
      refute output_xml =~ "@average_age@"
    end

    test "handles single person in table" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "Sarah"},
        "client" => "Tech Inc",
        "people" => [
          %{"first_name" => "Jane", "last_name" => "Doe", "age" => "30"}
        ],
        "average_age" => "30"
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      assert output_xml =~ "Sarah"
      assert output_xml =~ "Tech Inc"
      assert output_xml =~ "Jane"
      assert output_xml =~ "Doe"
      assert output_xml =~ "30"
    end

    test "handles empty people list" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "Manager"},
        "client" => "Empty Corp",
        "people" => [],
        "average_age" => "0"
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Should have the opening text and average
      assert output_xml =~ "Manager"
      assert output_xml =~ "0"

      # Template placeholders should not appear
      refute output_xml =~ "@people.first_name@"
    end

    test "handles numeric ages correctly" do
      # Arrange - test with actual numbers instead of strings
      data = %{
        "person" => %{"first_name" => "Analyst"},
        "client" => "Data Corp",
        "people" => [
          %{"first_name" => "Alex", "last_name" => "Taylor", "age" => 25},
          %{"first_name" => "Morgan", "last_name" => "Lee", "age" => 45}
        ],
        "average_age" => 35
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Numbers should be converted to strings
      assert output_xml =~ "25"
      assert output_xml =~ "45"
      assert output_xml =~ "35"
    end

    test "handles special characters in data" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "O'Brien"},
        "client" => "Smith & Associates",
        "people" => [
          %{"first_name" => "Jean-Luc", "last_name" => "Picard", "age" => "59"}
        ],
        "average_age" => "59"
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # XML should be well-formed
      assert {:ok, _parsed} = Ootempl.Xml.parse(output_xml)

      # Special chars should be escaped in XML
      # Apostrophe gets escaped to &apos; (which appears as &amp;apos; in serialized XML)
      assert output_xml =~ "&amp;apos;"
      # & should be double-escaped in the serialized XML
      assert output_xml =~ "&amp;amp;"
      # Hyphen is allowed as-is in XML
      assert output_xml =~ "Jean-Luc"
    end

    test "output is a valid .docx file" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "Test"},
        "client" => "Test Corp",
        "people" => [
          %{"first_name" => "Test", "last_name" => "User", "age" => "25"}
        ],
        "average_age" => "25"
      }

      # Act
      Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert :ok = Ootempl.Validator.validate_docx(@output_path)
    end

    test "preserves table structure and formatting" do
      # Arrange
      data = %{
        "person" => %{"first_name" => "Format"},
        "client" => "Style Corp",
        "people" => [
          %{"first_name" => "A", "last_name" => "B", "age" => "1"}
        ],
        "average_age" => "1"
      }

      # Get original table count
      {:ok, template_xml} = OotemplTestHelpers.extract_file_for_test(@template_path, "word/document.xml")
      {:ok, template_doc} = Ootempl.Xml.parse(template_xml)

      # Act
      Ootempl.render(@template_path, data, @output_path)

      # Assert
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")
      {:ok, output_doc} = Ootempl.Xml.parse(output_xml)

      # Document root should be the same
      assert xmlElement(template_doc, :name) == xmlElement(output_doc, :name)
    end

    test "returns error when required data is missing" do
      # Arrange - missing people list
      data = %{
        "person" => %{"first_name" => "John"}
        # Missing client, people, average_age
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert {:error, error} = result
      assert %Ootempl.PlaceholderError{} = error
      assert length(error.placeholders) > 0
    end

    test "handles large dataset efficiently" do
      # Arrange - generate 50 people
      people =
        for i <- 1..50 do
          %{
            "first_name" => "Person#{i}",
            "last_name" => "Lastname#{i}",
            "age" => "#{20 + rem(i, 50)}"
          }
        end

      data = %{
        "person" => %{"first_name" => "Manager"},
        "client" => "Big Corp",
        "people" => people,
        "average_age" => "45"
      }

      # Act
      result = Ootempl.render(@template_path, data, @output_path)

      # Assert
      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Spot check first, middle, and last entries
      assert output_xml =~ "Person1"
      assert output_xml =~ "Person25"
      assert output_xml =~ "Person50"
    end
  end

  describe "manual verification" do
    @tag :manual
    test "generates output for manual inspection in Microsoft Word" do
      # Arrange - create realistic test data
      data = %{
        "person" => %{"first_name" => "Jennifer"},
        "client" => "Global Enterprises Inc.",
        "people" => [
          %{"first_name" => "Michael", "last_name" => "Johnson", "age" => "32"},
          %{"first_name" => "Sarah", "last_name" => "Williams", "age" => "28"},
          %{"first_name" => "David", "last_name" => "Brown", "age" => "45"},
          %{"first_name" => "Emily", "last_name" => "Davis", "age" => "37"},
          %{"first_name" => "James", "last_name" => "Miller", "age" => "29"}
        ],
        "average_age" => "34.2"
      }

      # Don't clean up this file - leave it for manual verification
      on_exit(fn -> :ok end)

      # Act
      result = Ootempl.render(@template_path, data, @manual_output_path)

      # Assert
      assert result == :ok
      assert File.exists?(@manual_output_path)
      assert :ok = Ootempl.Validator.validate_docx(@manual_output_path)

      IO.puts("""

      ========================================
      MANUAL VERIFICATION REQUIRED
      ========================================

      Template: #{Path.basename(@template_path)}
      Output:   #{Path.expand(@manual_output_path)}

      Test Data Used:
      ---------------
      Person:       Jennifer
      Client:       Global Enterprises Inc.
      People Count: 5
      Average Age:  34.2

      Expected Content:
      -----------------
      1. Opening text: "This is a document for Jennifer:"
      2. Table with headers: Client, First Name, Last Name, Age
      3. Five rows of people data (Michael, Sarah, David, Emily, James)
      4. All people should show "Global Enterprises Inc." in the Client column
      5. Summary row with "Average Age: 34.2"

      Verification Steps:
      -------------------
      1. Open the file in Microsoft Word
      2. Verify it opens without errors or corruption warnings
      3. Check that the opening text displays "Jennifer"
      4. Verify the table contains 5 data rows (plus header and summary)
      5. Confirm all formatting is preserved (table borders, alignment, etc.)
      6. Verify the Client column shows "Global Enterprises Inc." for all rows
      7. Check that the average age (34.2) appears in the summary row

      To run this test:
      -----------------
      mix test test/integration/table_repeating_word_test.exs --only manual

      ========================================
      """)
    end
  end
end
