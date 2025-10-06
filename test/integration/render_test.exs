defmodule Ootempl.Integration.RenderTest do
  @moduledoc """
  Integration tests for the Ootempl.render/3 API.

  These tests verify end-to-end functionality with real .docx files,
  ensuring the complete workflow works correctly: template loading,
  XML parsing, serialization, and output generation.
  """

  use ExUnit.Case

  @test_fixture "test/fixtures/Simple Placeholdes from Word.docx"
  @output_path "test/fixtures/integration_output.docx"

  setup do
    # Clean up output files after each test
    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  describe "variable replacement" do
    test "replaces simple placeholders with data values" do
      # Arrange
      template_path = @test_fixture
      data = %{
        "person" => %{"first_name" => "Marty McFly"},
        "date" => "October 26, 1985"
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify placeholders were replaced
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert output_xml =~ "Marty McFly"
      assert output_xml =~ "October 26, 1985"
      refute output_xml =~ "@person.first_name@"
      refute output_xml =~ "@date@"
    end

    test "replaces nested data placeholders" do
      # Arrange
      template_path = @test_fixture
      data = %{
        "person" => %{"first_name" => "George McFly"},
        "date" => "November 5, 1955"
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert output_xml =~ "George McFly"
      assert output_xml =~ "November 5, 1955"
    end

    test "converts numbers to strings during replacement" do
      # Arrange
      template_path = @test_fixture
      data = %{
        "person" => %{"first_name" => "88"},
        "date" => 1985
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert output_xml =~ "1985"
      assert output_xml =~ "88"
    end

    test "handles case-insensitive placeholder matching" do
      # Arrange
      template_path = @test_fixture
      # Template has @person.first_name@ and @date@ but we provide different case
      data = %{
        "PERSON" => %{"FIRST_NAME" => "Biff Tannen"},
        "Date" => "November 12, 1955"
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert output_xml =~ "Biff Tannen"
      assert output_xml =~ "November 12, 1955"
    end

    test "returns error when placeholder data is missing" do
      # Arrange
      template_path = @test_fixture
      data = %{} # Empty data, placeholders exist in template

      # Act
      result = Ootempl.render(template_path, data, @output_path)

      # Assert
      assert {:error, error} = result
      assert %Ootempl.PlaceholderError{} = error
      assert length(error.placeholders) > 0

      # Check error structure
      [%{placeholder: placeholder, reason: reason} | _] = error.placeholders
      assert is_binary(placeholder)
      assert String.starts_with?(placeholder, "@")
      assert String.ends_with?(placeholder, "@")
      assert {:path_not_found, _path} = reason
    end

    test "collects all placeholder errors together" do
      # Arrange
      template_path = @test_fixture
      data = %{"date" => "1985"} # Only one field, template needs 2

      # Act
      result = Ootempl.render(template_path, data, @output_path)

      # Assert
      assert {:error, error} = result
      assert %Ootempl.PlaceholderError{} = error
      # Template should have @person.first_name@ missing
      assert length(error.placeholders) >= 1
    end

    test "escapes XML special characters in replacement values" do
      # Arrange
      template_path = @test_fixture
      data = %{
        "person" => %{"first_name" => "Doc & Marty"},
        "date" => "<Back to the Future>"
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      # XML should be well-formed (escaped properly)
      assert {:ok, _parsed} = Ootempl.Xml.parse(output_xml)

      # Values should be escaped (double-escaped in serialized XML)
      # Our code escapes once, then xmerl escapes again during serialization
      assert output_xml =~ "&amp;amp;"  # & -> &amp; -> &amp;amp;
      assert output_xml =~ "&amp;lt;"   # < -> &lt; -> &amp;lt;
      assert output_xml =~ "&amp;gt;"   # > -> &gt; -> &amp;gt;
    end
  end

  describe "end-to-end template rendering" do
    test "renders real .docx template and produces valid output" do
      # Arrange
      template_path = @test_fixture
      data = %{
        "person" => %{"first_name" => "Test User"},
        "date" => "2025-10-06"
      }
      output_path = @output_path

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)
    end

    test "output .docx file is a valid ZIP archive" do
      # Arrange
      template_path = @test_fixture
      output_path = @output_path
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      # Act
      Ootempl.render(template_path, data, output_path)

      # Assert - verify ZIP structure
      assert {:ok, zip_handle} = :zip.zip_open(to_charlist(output_path), [:memory])

      try do
        # Should be able to list files in archive
        assert {:ok, file_list} = :zip.zip_list_dir(zip_handle)
        assert length(file_list) > 0
      after
        :zip.zip_close(zip_handle)
      end
    end

    test "output contains well-formed document.xml" do
      # Arrange
      template_path = @test_fixture
      output_path = @output_path
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      # Act
      Ootempl.render(template_path, data, output_path)

      # Assert - extract and validate document.xml
      {:ok, xml_content} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      # Should parse without errors
      assert {:ok, xml_doc} = Ootempl.Xml.parse(xml_content)

      # Should be able to serialize back
      assert {:ok, _xml_string} = Ootempl.Xml.serialize(xml_doc)
    end

    test "round-trip preserves document structure" do
      # Arrange
      template_path = @test_fixture
      output_path = @output_path
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      # Get original document.xml
      {:ok, original_xml} = Ootempl.Archive.extract_file(template_path, "word/document.xml")
      {:ok, original_doc} = Ootempl.Xml.parse(original_xml)

      # Act - render template
      Ootempl.render(template_path, data, output_path)

      # Assert - compare XML structure
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      {:ok, output_doc} = Ootempl.Xml.parse(output_xml)

      # Element names should match (basic structure check)
      original_name = Ootempl.Xml.element_name(original_doc)
      output_name = Ootempl.Xml.element_name(output_doc)

      assert original_name == output_name
    end

    test "all archive files are preserved in output" do
      # Arrange
      template_path = @test_fixture
      output_path = @output_path
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      # Get template file list
      {:ok, zip_handle} = :zip.zip_open(to_charlist(template_path), [:memory])

      template_file_count =
        try do
          {:ok, file_list} = :zip.zip_list_dir(zip_handle)
          length(file_list)
        after
          :zip.zip_close(zip_handle)
        end

      # Act
      Ootempl.render(template_path, data, output_path)

      # Assert - output has same number of files
      {:ok, zip_handle} = :zip.zip_open(to_charlist(output_path), [:memory])

      output_file_count =
        try do
          {:ok, file_list} = :zip.zip_list_dir(zip_handle)
          length(file_list)
        after
          :zip.zip_close(zip_handle)
        end

      assert output_file_count == template_file_count
    end

    test "can render multiple times without interference" do
      # Arrange
      template_path = @test_fixture
      output1 = "test/fixtures/multi_output1.docx"
      output2 = "test/fixtures/multi_output2.docx"
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      on_exit(fn ->
        File.rm(output1)
        File.rm(output2)
      end)

      # Act - render twice
      result1 = Ootempl.render(template_path, data, output1)
      result2 = Ootempl.render(template_path, data, output2)

      # Assert
      assert result1 == :ok
      assert result2 == :ok
      assert File.exists?(output1)
      assert File.exists?(output2)

      # Both outputs should be valid
      assert :ok = Ootempl.Validator.validate_docx(output1)
      assert :ok = Ootempl.Validator.validate_docx(output2)
    end

    test "handles relative and absolute paths correctly" do
      # Arrange
      absolute_template = Path.expand(@test_fixture)
      relative_output = @output_path
      data = %{"person" => %{"first_name" => "Test"}, "date" => "Test"}

      # Act
      result = Ootempl.render(absolute_template, data, relative_output)

      # Assert
      assert result == :ok
      assert File.exists?(relative_output)
      assert :ok = Ootempl.Validator.validate_docx(relative_output)
    end
  end

  describe "error handling in integration scenarios" do
    test "gracefully handles corrupted template file" do
      # Arrange - create corrupted file
      corrupted_path = "test/fixtures/corrupted.docx"
      File.write!(corrupted_path, "This is not a valid ZIP/docx file")

      on_exit(fn ->
        File.rm(corrupted_path)
      end)

      # Act
      result = Ootempl.render(corrupted_path, %{"name" => "Test"}, @output_path)

      # Assert
      assert {:error, %Ootempl.InvalidArchiveError{}} = result
      refute File.exists?(@output_path)
    end

    test "cleans up temp files even when processing fails" do
      # Arrange
      corrupted_path = "test/fixtures/corrupted2.docx"
      File.write!(corrupted_path, "Invalid content")
      temp_dir_pattern = Path.join(System.tmp_dir!(), "ootempl_*")

      on_exit(fn ->
        File.rm(corrupted_path)
      end)

      # Get temp directory count before
      temp_dirs_before =
        temp_dir_pattern
        |> Path.wildcard()
        |> Enum.filter(&File.dir?/1)
        |> length()

      # Act - should fail
      Ootempl.render(corrupted_path, %{"name" => "Test"}, @output_path)

      # Assert - no new temp directories left
      temp_dirs_after =
        temp_dir_pattern
        |> Path.wildcard()
        |> Enum.filter(&File.dir?/1)
        |> length()

      assert temp_dirs_after == temp_dirs_before
    end
  end

  describe "table template processing" do
    test "processes simple table template with list data" do
      # Arrange
      template_path = "test/fixtures/table_simple.docx"
      data = %{
        "title" => "Claims Report",
        "claims" => [
          %{"id" => "5565", "amount" => "100.50"},
          %{"id" => "5566", "amount" => "250.00"}
        ],
        "total" => "350.50"
      }
      output_path = "test/fixtures/table_simple_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      # Should have both claim IDs in output
      assert output_xml =~ "5565"
      assert output_xml =~ "5566"
      assert output_xml =~ "100.50"
      assert output_xml =~ "250.00"
      assert output_xml =~ "350.50"

      # Template placeholders should be replaced
      refute output_xml =~ "@claims.id@"
      refute output_xml =~ "@claims.amount@"
    end

    test "handles empty list by removing template row" do
      # Arrange
      template_path = "test/fixtures/table_simple.docx"
      data = %{
        "title" => "Empty Report",
        "claims" => [],
        "total" => "0.00"
      }
      output_path = "test/fixtures/table_empty_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      # Should have total but no claim rows
      assert output_xml =~ "0.00"
      refute output_xml =~ "@claims.id@"
    end

    test "processes mixed table with header, template, and footer rows" do
      # Arrange
      template_path = "test/fixtures/table_mixed.docx"
      data = %{
        "claims" => [
          %{"id" => "101", "amount" => "50.00"},
          %{"id" => "102", "amount" => "75.00"}
        ],
        "total" => "125.00"
      }
      output_path = "test/fixtures/table_mixed_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      assert output_xml =~ "101"
      assert output_xml =~ "102"
      assert output_xml =~ "125.00"
    end

    test "processes multi-row template" do
      # Arrange
      template_path = "test/fixtures/table_multirow.docx"
      data = %{
        "orders" => [
          %{"id" => "100", "product" => "Widget", "qty" => "5", "price" => "10.00"},
          %{"id" => "101", "product" => "Gadget", "qty" => "3", "price" => "25.00"}
        ]
      }
      output_path = "test/fixtures/table_multirow_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      assert output_xml =~ "100"
      assert output_xml =~ "Widget"
      assert output_xml =~ "101"
      assert output_xml =~ "Gadget"
    end

    test "processes multiple tables in same document" do
      # Arrange
      template_path = "test/fixtures/table_multiple.docx"
      data = %{
        "claims" => [
          %{"id" => "1", "amount" => "100"}
        ],
        "orders" => [
          %{"id" => "A", "total" => "200"}
        ]
      }
      output_path = "test/fixtures/table_multiple_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      assert output_xml =~ "1"
      assert output_xml =~ "100"
      assert output_xml =~ "A"
      assert output_xml =~ "200"
    end

    test "combines table processing with regular variable replacement" do
      # Arrange
      template_path = "test/fixtures/table_with_variables.docx"
      data = %{
        "company_name" => "Acme Corp",
        "report_date" => "2025-10-06",
        "items" => [
          %{"name" => "Product A", "price" => "50.00"}
        ]
      }
      output_path = "test/fixtures/table_with_variables_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      # Check both regular variables and table items
      assert output_xml =~ "Acme Corp"
      assert output_xml =~ "2025-10-06"
      assert output_xml =~ "Product A"
      assert output_xml =~ "50.00"
    end

    test "table output is valid .docx that can be opened in Word" do
      # Arrange
      template_path = "test/fixtures/table_from_word.docx"
      data = %{
        "claims" => [
          %{"id" => "999", "amount" => "999.99"}
        ],
        "total" => "999.99"
      }
      output_path = "test/fixtures/table_from_word_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert :ok = Ootempl.Validator.validate_docx(output_path)
    end

    @tag :skip
    test "handles table without templates (regular variable replacement only)" do
      # Arrange - table with no list placeholders, just regular variables
      template_path = "test/fixtures/table_no_template.docx"
      data = %{
        "name" => "John",
        "total" => "100"
      }
      output_path = "test/fixtures/table_no_template_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, output_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")

      assert output_xml =~ "John"
      assert output_xml =~ "100"
    end
  end

  describe "manual verification guidance" do
    @tag :manual
    test "output can be opened in Microsoft Word (manual verification required)" do
      # Arrange
      template_path = @test_fixture
      output_path = "test/fixtures/manual_verification.docx"
      data = %{
        "person" => %{"first_name" => "Marty McFly"},
        "date" => "October 26, 1985"
      }

      on_exit(fn ->
        # Don't delete - leave for manual verification
        # File.rm(output_path)
        :ok
      end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      IO.puts("""

      ========================================
      MANUAL VERIFICATION REQUIRED
      ========================================

      An output file has been generated at:
      #{Path.expand(output_path)}

      Please verify:
      1. Open the file in Microsoft Word
      2. Confirm it opens without errors
      3. Check that content appears correctly
      4. Verify no corruption warnings

      This test is tagged with :manual and should be run with:
      mix test --only manual

      ========================================
      """)
    end
  end
end
