defmodule Ootempl.ValidatorTest do
  use ExUnit.Case, async: true

  alias Ootempl.InvalidArchiveError
  alias Ootempl.MalformedXMLError
  alias Ootempl.MissingFileError
  alias Ootempl.ValidationError
  alias Ootempl.Validator

  @fixtures_dir Path.join([__DIR__, "..", "fixtures"])
  @valid_docx Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

  setup_all do
    # Create test fixtures programmatically
    create_test_fixtures(@fixtures_dir)

    on_exit(fn ->
      cleanup_test_fixtures(@fixtures_dir)
    end)

    :ok
  end

  describe "validate_archive/1" do
    # Arrange, Act, Assert

    test "returns :ok for valid .docx file" do
      # Arrange
      path = @valid_docx

      # Act
      result = Validator.validate_archive(path)

      # Assert
      assert result == :ok
    end

    test "returns error for corrupt ZIP file" do
      # Arrange
      path = Path.join(@fixtures_dir, "corrupt.docx")

      # Act
      {:error, exception} = Validator.validate_archive(path)

      # Assert
      assert %InvalidArchiveError{} = exception
      assert exception.path == path
      assert is_atom(exception.reason) or is_tuple(exception.reason)
    end

    test "returns error for non-existent file" do
      # Arrange
      path = Path.join(@fixtures_dir, "nonexistent.docx")

      # Act
      {:error, exception} = Validator.validate_archive(path)

      # Assert
      assert %InvalidArchiveError{} = exception
      assert exception.path == path
    end
  end

  describe "validate_structure/1" do
    # Arrange, Act, Assert

    test "returns :ok for .docx with all required files" do
      # Arrange
      path = @valid_docx

      # Act
      result = Validator.validate_structure(path)

      # Assert
      assert result == :ok
    end

    test "returns error when document.xml is missing" do
      # Arrange
      path = Path.join(@fixtures_dir, "incomplete.docx")

      # Act
      {:error, exception} = Validator.validate_structure(path)

      # Assert
      assert %MissingFileError{} = exception
      assert exception.path == path
      assert exception.missing_file == "word/document.xml"
    end

    test "returns error for invalid ZIP archive" do
      # Arrange
      path = Path.join(@fixtures_dir, "corrupt.docx")

      # Act
      {:error, exception} = Validator.validate_structure(path)

      # Assert
      assert %InvalidArchiveError{} = exception
    end
  end

  describe "validate_xml/1" do
    # Arrange, Act, Assert

    test "returns :ok for well-formed XML" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <root>
        <child>text</child>
      </root>
      """

      # Act
      result = Validator.validate_xml(xml)

      # Assert
      assert result == :ok
    end

    test "returns :ok for XML with namespaces" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>Hello World</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """

      # Act
      result = Validator.validate_xml(xml)

      # Assert
      assert result == :ok
    end

    test "returns error for malformed XML with unclosed tag" do
      # Arrange
      xml = "<root><unclosed>"

      # Act
      {:error, reason} = Validator.validate_xml(xml)

      # Assert
      assert is_tuple(reason) or is_exception(reason)
    end

    test "returns error for XML with mismatched tags" do
      # Arrange
      xml = "<root><child></wrongtag></root>"

      # Act
      {:error, reason} = Validator.validate_xml(xml)

      # Assert
      assert is_tuple(reason) or is_exception(reason)
    end

    test "returns error for empty string" do
      # Arrange
      xml = ""

      # Act
      {:error, reason} = Validator.validate_xml(xml)

      # Assert
      assert is_tuple(reason) or is_exception(reason)
    end
  end

  describe "validate_docx/1" do
    # Arrange, Act, Assert

    test "returns :ok for valid .docx file" do
      # Arrange
      path = @valid_docx

      # Act
      result = Validator.validate_docx(path)

      # Assert
      assert result == :ok
    end

    test "returns ValidationError when file does not exist" do
      # Arrange
      path = Path.join(@fixtures_dir, "nonexistent.docx")

      # Act
      {:error, exception} = Validator.validate_docx(path)

      # Assert
      assert %ValidationError{} = exception
      assert exception.path == path
      assert exception.reason == :file_not_found
      assert exception.message =~ "File not found"
    end

    test "returns ValidationError when path is a directory" do
      # Arrange
      path = @fixtures_dir

      # Act
      {:error, exception} = Validator.validate_docx(path)

      # Assert
      assert %ValidationError{} = exception
      assert exception.path == path
      assert exception.reason == :not_a_file
      assert exception.message =~ "Not a regular file"
    end

    test "returns InvalidArchiveError for corrupt ZIP" do
      # Arrange
      path = Path.join(@fixtures_dir, "corrupt.docx")

      # Act
      {:error, exception} = Validator.validate_docx(path)

      # Assert
      assert %InvalidArchiveError{} = exception
      assert exception.path == path
    end

    test "returns MissingFileError for incomplete .docx structure" do
      # Arrange
      path = Path.join(@fixtures_dir, "incomplete.docx")

      # Act
      {:error, exception} = Validator.validate_docx(path)

      # Assert
      assert %MissingFileError{} = exception
      assert exception.path == path
      assert exception.missing_file == "word/document.xml"
    end

    test "returns MalformedXMLError for .docx with invalid XML" do
      # Arrange
      path = Path.join(@fixtures_dir, "malformed.docx")

      # Act
      {:error, exception} = Validator.validate_docx(path)

      # Assert
      assert %MalformedXMLError{} = exception
      assert exception.path == path
      assert exception.xml_file == "word/document.xml"
    end
  end

  # Helper functions for creating and cleaning up test fixtures

  defp create_test_fixtures(fixtures_dir) do
    # Create corrupt.docx (not a valid ZIP)
    corrupt_path = Path.join(fixtures_dir, "corrupt.docx")
    File.write!(corrupt_path, "This is not a ZIP file")

    # Create incomplete.docx (missing word/document.xml)
    create_incomplete_docx(fixtures_dir)

    # Create malformed.docx (has invalid XML in document.xml)
    create_malformed_docx(fixtures_dir)
  end

  defp create_incomplete_docx(fixtures_dir) do
    temp_dir = Path.join(fixtures_dir, "temp_incomplete")
    File.mkdir_p!(temp_dir)
    File.mkdir_p!(Path.join(temp_dir, "_rels"))

    # Create [Content_Types].xml
    content_types = """
    <?xml version="1.0"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    </Types>
    """

    File.write!(Path.join(temp_dir, "[Content_Types].xml"), content_types)

    # Create _rels/.rels
    rels = """
    <?xml version="1.0"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """

    File.write!(Path.join([temp_dir, "_rels", ".rels"]), rels)

    # Create ZIP without word/document.xml
    output_path = Path.join(fixtures_dir, "incomplete.docx")
    create_zip_from_directory(temp_dir, output_path)

    # Cleanup
    File.rm_rf!(temp_dir)
  end

  defp create_malformed_docx(fixtures_dir) do
    temp_dir = Path.join(fixtures_dir, "temp_malformed")
    File.mkdir_p!(temp_dir)
    File.mkdir_p!(Path.join(temp_dir, "_rels"))
    File.mkdir_p!(Path.join(temp_dir, "word"))

    # Create [Content_Types].xml
    content_types = """
    <?xml version="1.0"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    </Types>
    """

    File.write!(Path.join(temp_dir, "[Content_Types].xml"), content_types)

    # Create _rels/.rels
    rels = """
    <?xml version="1.0"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """

    File.write!(Path.join([temp_dir, "_rels", ".rels"]), rels)

    # Create malformed word/document.xml
    malformed_xml = "<unclosed><tag>"
    File.write!(Path.join([temp_dir, "word", "document.xml"]), malformed_xml)

    # Create ZIP
    output_path = Path.join(fixtures_dir, "malformed.docx")
    create_zip_from_directory(temp_dir, output_path)

    # Cleanup
    File.rm_rf!(temp_dir)
  end

  defp create_zip_from_directory(source_dir, output_path) do
    # Get all files in the directory recursively, including hidden files
    files = collect_files(source_dir, source_dir)

    # Create ZIP archive
    :zip.create(String.to_charlist(output_path), files)
  end

  defp collect_files(current_dir, base_dir) do
    current_dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      full_path = Path.join(current_dir, entry)

      cond do
        File.regular?(full_path) ->
          relative_path = Path.relative_to(full_path, base_dir)
          content = File.read!(full_path)
          [{String.to_charlist(relative_path), content}]

        File.dir?(full_path) ->
          collect_files(full_path, base_dir)

        true ->
          []
      end
    end)
  end

  defp cleanup_test_fixtures(fixtures_dir) do
    # Remove generated test fixtures
    for file <- ["corrupt.docx", "incomplete.docx", "malformed.docx"] do
      path = Path.join(fixtures_dir, file)
      File.rm(path)
    end
  end
end
