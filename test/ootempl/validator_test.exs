defmodule Ootempl.ValidatorTest do
  use ExUnit.Case, async: true

  alias Ootempl.InvalidArchiveError
  alias Ootempl.MalformedXMLError
  alias Ootempl.MissingFileError
  alias Ootempl.ValidationError
  alias Ootempl.Validator

  @valid_template "test/fixtures/Simple Placeholdes from Word.docx"

  describe "validate_docx/1 - success cases" do
    test "validates a correct .docx file" do
      # Arrange
      path = @valid_template

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert result == :ok
    end

    test "validates template with images" do
      # Arrange
      path = "test/fixtures/image_simple.docx"

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert result == :ok
    end

    test "validates template with tables" do
      # Arrange
      path = "test/fixtures/Table Repeating Rows from Word.docx"

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert result == :ok
    end
  end

  describe "validate_docx/1 - file existence errors" do
    test "returns error for non-existent file" do
      # Arrange
      path = "test/fixtures/nonexistent.docx"

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert {:error, %ValidationError{}} = result
      {:error, error} = result
      assert error.reason == :file_not_found
      assert error.path == path
    end

    test "returns error for directory instead of file" do
      # Arrange
      # Use the test/fixtures directory itself
      path = "test/fixtures"

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert {:error, %ValidationError{}} = result
      {:error, error} = result
      assert error.reason == :not_a_file
      assert error.path == path
    end
  end

  describe "validate_docx/1 - invalid archive errors" do
    test "returns error for corrupt ZIP archive" do
      # Arrange
      corrupt_path = "test/fixtures/corrupt_archive.docx"
      File.write!(corrupt_path, "This is not a ZIP file")

      # Act
      result = Validator.validate_docx(corrupt_path)

      # Cleanup
      File.rm!(corrupt_path)

      # Assert
      assert {:error, %InvalidArchiveError{}} = result
      {:error, error} = result
      assert error.path == corrupt_path
      assert error.reason
    end

    test "returns error for empty file" do
      # Arrange
      empty_path = "test/fixtures/empty.docx"
      File.write!(empty_path, "")

      # Act
      result = Validator.validate_docx(empty_path)

      # Cleanup
      File.rm!(empty_path)

      # Assert
      assert {:error, %InvalidArchiveError{}} = result
      {:error, error} = result
      assert error.path == empty_path
    end

    test "returns error for partially corrupt ZIP" do
      # Arrange
      partial_path = "test/fixtures/partial.docx"
      # Write a ZIP header but incomplete content
      File.write!(partial_path, <<80, 75, 3, 4>>)

      # Act
      result = Validator.validate_docx(partial_path)

      # Cleanup
      File.rm!(partial_path)

      # Assert
      assert {:error, %InvalidArchiveError{}} = result
    end
  end

  describe "validate_docx/1 - missing required files" do
    test "returns error when word/document.xml is missing" do
      # Arrange
      # Create a minimal ZIP without word/document.xml
      missing_doc_path = "test/fixtures/missing_document.docx"

      files = [
        {~c"[Content_Types].xml", "<Types/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(missing_doc_path), files)

      # Act
      result = Validator.validate_docx(missing_doc_path)

      # Cleanup
      File.rm!(missing_doc_path)

      # Assert
      assert {:error, %MissingFileError{}} = result
      {:error, error} = result
      assert error.missing_file == "word/document.xml"
      assert error.path == missing_doc_path
    end

    test "returns error when [Content_Types].xml is missing" do
      # Arrange
      missing_content_types_path = "test/fixtures/missing_content_types.docx"

      files = [
        {~c"word/document.xml", "<document/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(missing_content_types_path), files)

      # Act
      result = Validator.validate_docx(missing_content_types_path)

      # Cleanup
      File.rm!(missing_content_types_path)

      # Assert
      assert {:error, %MissingFileError{}} = result
      {:error, error} = result
      assert error.missing_file == "[Content_Types].xml"
    end

    test "returns error when _rels/.rels is missing" do
      # Arrange
      missing_rels_path = "test/fixtures/missing_rels.docx"

      files = [
        {~c"word/document.xml", "<document/>"},
        {~c"[Content_Types].xml", "<Types/>"}
      ]

      :zip.create(to_charlist(missing_rels_path), files)

      # Act
      result = Validator.validate_docx(missing_rels_path)

      # Cleanup
      File.rm!(missing_rels_path)

      # Assert
      assert {:error, %MissingFileError{}} = result
      {:error, error} = result
      assert error.missing_file == "_rels/.rels"
    end

    test "returns first missing file when multiple files are missing" do
      # Arrange
      multiple_missing_path = "test/fixtures/multiple_missing.docx"

      # Only include one of the three required files
      files = [
        {~c"word/document.xml", "<document/>"}
      ]

      :zip.create(to_charlist(multiple_missing_path), files)

      # Act
      result = Validator.validate_docx(multiple_missing_path)

      # Cleanup
      File.rm!(multiple_missing_path)

      # Assert
      assert {:error, %MissingFileError{}} = result
      {:error, error} = result
      # Should report one of the missing files
      assert error.missing_file in ["[Content_Types].xml", "_rels/.rels"]
    end
  end

  describe "validate_docx/1 - malformed XML errors" do
    test "returns error for malformed word/document.xml" do
      # Arrange
      malformed_xml_path = "test/fixtures/malformed_xml.docx"

      files = [
        {~c"word/document.xml", "<document><unclosed>"},
        {~c"[Content_Types].xml", "<Types/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(malformed_xml_path), files)

      # Act
      result = Validator.validate_docx(malformed_xml_path)

      # Cleanup
      File.rm!(malformed_xml_path)

      # Assert
      assert {:error, %MalformedXMLError{}} = result
      {:error, error} = result
      assert error.xml_file == "word/document.xml"
      assert error.path == malformed_xml_path
      assert error.reason != :unknown
    end

    test "returns error for document.xml with invalid characters" do
      # Arrange
      invalid_chars_path = "test/fixtures/invalid_chars_xml.docx"

      # Use a control character that's invalid in XML
      files = [
        {~c"word/document.xml", "<document>\x00</document>"},
        {~c"[Content_Types].xml", "<Types/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(invalid_chars_path), files)

      # Act
      result = Validator.validate_docx(invalid_chars_path)

      # Cleanup
      File.rm!(invalid_chars_path)

      # Assert
      assert {:error, %MalformedXMLError{}} = result
    end

    test "returns error for empty document.xml" do
      # Arrange
      empty_xml_path = "test/fixtures/empty_xml.docx"

      files = [
        {~c"word/document.xml", ""},
        {~c"[Content_Types].xml", "<Types/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(empty_xml_path), files)

      # Act
      result = Validator.validate_docx(empty_xml_path)

      # Cleanup
      File.rm!(empty_xml_path)

      # Assert
      assert {:error, %MalformedXMLError{}} = result
    end

    test "validates well-formed but minimal document.xml" do
      # Arrange
      minimal_xml_path = "test/fixtures/minimal_xml.docx"

      files = [
        {~c"word/document.xml",
         ~s(<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body/></w:document>)},
        {~c"[Content_Types].xml", "<Types/>"},
        {~c"_rels/.rels", "<Relationships/>"}
      ]

      :zip.create(to_charlist(minimal_xml_path), files)

      # Act
      result = Validator.validate_docx(minimal_xml_path)

      # Cleanup
      File.rm!(minimal_xml_path)

      # Assert
      assert result == :ok
    end
  end

  describe "validate_docx/1 - validation order" do
    test "checks file existence before archive validation" do
      # Arrange
      nonexistent_path = "test/fixtures/does_not_exist.docx"

      # Act
      result = Validator.validate_docx(nonexistent_path)

      # Assert
      # Should fail at file existence check, not archive validation
      assert {:error, %ValidationError{reason: :file_not_found}} = result
    end

    test "checks archive validity before structure validation" do
      # Arrange
      corrupt_path = "test/fixtures/corrupt_for_order_test.docx"
      File.write!(corrupt_path, "not a zip")

      # Act
      result = Validator.validate_docx(corrupt_path)

      # Cleanup
      File.rm!(corrupt_path)

      # Assert
      # Should fail at archive validation, not structure validation
      assert {:error, %InvalidArchiveError{}} = result
    end

    test "checks structure before XML validation" do
      # Arrange
      missing_file_path = "test/fixtures/missing_for_order_test.docx"

      # Create ZIP with malformed XML but missing required file
      files = [
        {~c"word/document.xml", "<invalid><xml>"}
        # Missing [Content_Types].xml and _rels/.rels
      ]

      :zip.create(to_charlist(missing_file_path), files)

      # Act
      result = Validator.validate_docx(missing_file_path)

      # Cleanup
      File.rm!(missing_file_path)

      # Assert
      # Should fail at structure validation before XML validation
      assert {:error, %MissingFileError{}} = result
    end
  end

  describe "validate_docx/1 - edge cases" do
    test "handles very large valid .docx files" do
      # Arrange
      # Use an existing fixture (assuming it's reasonably sized)
      path = @valid_template

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert result == :ok
    end

    test "handles paths with spaces" do
      # Arrange
      space_path = "test/fixtures/temp with spaces.docx"
      File.cp!(@valid_template, space_path)

      # Act
      result = Validator.validate_docx(space_path)

      # Cleanup
      File.rm!(space_path)

      # Assert
      assert result == :ok
    end

    test "handles paths with special characters" do
      # Arrange
      special_path = "test/fixtures/temp-special_file(1).docx"
      File.cp!(@valid_template, special_path)

      # Act
      result = Validator.validate_docx(special_path)

      # Cleanup
      File.rm!(special_path)

      # Assert
      assert result == :ok
    end

    test "handles Unicode characters in path" do
      # Arrange
      unicode_path = "test/fixtures/文档.docx"
      File.cp!(@valid_template, unicode_path)

      # Act
      result = Validator.validate_docx(unicode_path)

      # Cleanup
      File.rm!(unicode_path)

      # Assert
      assert result == :ok
    end
  end
end
