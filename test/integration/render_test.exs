defmodule Ootempl.Integration.RenderTest do
  use ExUnit.Case

  @moduledoc """
  Integration tests for the Ootempl.render/3 API.

  These tests verify end-to-end functionality with real .docx files,
  ensuring the complete workflow works correctly: template loading,
  XML parsing, serialization, and output generation.
  """

  @test_fixture "test/fixtures/Simple Placeholdes from Word.docx"
  @output_path "test/fixtures/integration_output.docx"

  setup do
    # Clean up output files after each test
    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  describe "end-to-end template rendering" do
    test "renders real .docx template and produces valid output" do
      # Arrange
      template_path = @test_fixture
      data = %{}
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

      # Act
      Ootempl.render(template_path, %{}, output_path)

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

      # Act
      Ootempl.render(template_path, %{}, output_path)

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

      # Get original document.xml
      {:ok, original_xml} = Ootempl.Archive.extract_file(template_path, "word/document.xml")
      {:ok, original_doc} = Ootempl.Xml.parse(original_xml)

      # Act - render template
      Ootempl.render(template_path, %{}, output_path)

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
      Ootempl.render(template_path, %{}, output_path)

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

      on_exit(fn ->
        File.rm(output1)
        File.rm(output2)
      end)

      # Act - render twice
      result1 = Ootempl.render(template_path, %{}, output1)
      result2 = Ootempl.render(template_path, %{}, output2)

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

      # Act
      result = Ootempl.render(absolute_template, %{}, relative_output)

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
      result = Ootempl.render(corrupted_path, %{}, @output_path)

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
        Path.wildcard(temp_dir_pattern)
        |> Enum.filter(&File.dir?/1)
        |> length()

      # Act - should fail
      Ootempl.render(corrupted_path, %{}, @output_path)

      # Assert - no new temp directories left
      temp_dirs_after =
        Path.wildcard(temp_dir_pattern)
        |> Enum.filter(&File.dir?/1)
        |> length()

      assert temp_dirs_after == temp_dirs_before
    end
  end

  describe "manual verification guidance" do
    @tag :manual
    test "output can be opened in Microsoft Word (manual verification required)" do
      # Arrange
      template_path = @test_fixture
      output_path = "test/fixtures/manual_verification.docx"

      on_exit(fn ->
        # Don't delete - leave for manual verification
        # File.rm(output_path)
        :ok
      end)

      # Act
      result = Ootempl.render(template_path, %{}, output_path)

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
