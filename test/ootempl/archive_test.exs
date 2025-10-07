defmodule Ootempl.ArchiveTest do
  use ExUnit.Case, async: true

  alias Ootempl.Archive
  alias Ootempl.FixtureHelper

  @fixture_path "test/tmp/test_fixture.docx"
  @output_path "test/tmp/test_output.docx"

  setup do
    File.mkdir_p!("test/tmp")

    on_exit(fn ->
      File.rm_rf("test/tmp")
    end)

    :ok
  end

  describe "extract/1" do
    test "successfully extracts a valid .docx file" do
      # Arrange
      FixtureHelper.create_minimal_docx(@fixture_path)

      # Act
      result = Archive.extract(@fixture_path)

      # Assert
      assert {:ok, temp_path} = result
      assert File.exists?(temp_path)
      assert File.exists?(Path.join(temp_path, "word/document.xml"))
      assert File.exists?(Path.join(temp_path, "[Content_Types].xml"))

      # Cleanup
      Archive.cleanup(temp_path)
    end

    test "returns error when file does not exist" do
      # Arrange
      non_existent_path = "test/tmp/nonexistent.docx"

      # Act
      result = Archive.extract(non_existent_path)

      # Assert
      assert {:error, :file_not_found} = result
    end

    test "returns error when path is not a file" do
      # Arrange
      dir_path = "test/tmp/directory"
      File.mkdir_p!(dir_path)

      # Act
      result = Archive.extract(dir_path)

      # Assert
      assert {:error, :not_a_file} = result
    end

    test "returns error for invalid ZIP file" do
      # Arrange
      invalid_zip_path = "test/tmp/invalid.docx"
      File.write!(invalid_zip_path, "not a zip file")

      # Act
      result = Archive.extract(invalid_zip_path)

      # Assert
      assert {:error, _reason} = result
    end
  end

  describe "create/2" do
    test "successfully creates a .docx archive from file map" do
      # Arrange
      file_map = %{
        "[Content_Types].xml" => "<?xml version=\"1.0\"?><Types></Types>",
        "word/document.xml" => "<?xml version=\"1.0\"?><document></document>"
      }

      # Act
      result = Archive.create(file_map, @output_path)

      # Assert
      assert :ok = result
      assert File.exists?(@output_path)

      # Verify the archive contains the files
      {:ok, temp_path} = Archive.extract(@output_path)
      assert File.exists?(Path.join(temp_path, "[Content_Types].xml"))
      assert File.exists?(Path.join(temp_path, "word/document.xml"))
      Archive.cleanup(temp_path)
    end

    test "creates archive with multiple files in subdirectories" do
      # Arrange
      file_map = %{
        "[Content_Types].xml" => "content types",
        "_rels/.rels" => "relationships",
        "word/document.xml" => "document",
        "word/_rels/document.xml.rels" => "document relationships"
      }

      # Act
      result = Archive.create(file_map, @output_path)

      # Assert
      assert :ok = result

      # Verify structure is preserved
      {:ok, temp_path} = Archive.extract(@output_path)
      assert File.exists?(Path.join(temp_path, "[Content_Types].xml"))
      assert File.exists?(Path.join(temp_path, "_rels/.rels"))
      assert File.exists?(Path.join(temp_path, "word/document.xml"))
      assert File.exists?(Path.join(temp_path, "word/_rels/document.xml.rels"))
      Archive.cleanup(temp_path)
    end

    test "preserves file content exactly" do
      # Arrange
      original_content = "<?xml version=\"1.0\"?>\n<document>Test Content</document>"
      file_map = %{"word/document.xml" => original_content}

      # Act
      Archive.create(file_map, @output_path)

      # Assert
      {:ok, extracted_content} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")
      assert extracted_content == original_content
    end

    test "returns error for invalid output path" do
      # Arrange
      file_map = %{"test.xml" => "content"}
      invalid_path = "/nonexistent/directory/output.docx"

      # Act
      result = Archive.create(file_map, invalid_path)

      # Assert
      assert {:error, _reason} = result
    end
  end

  describe "cleanup/1" do
    test "successfully removes temporary directory" do
      # Arrange
      FixtureHelper.create_minimal_docx(@fixture_path)
      {:ok, temp_path} = Archive.extract(@fixture_path)
      assert File.exists?(temp_path)

      # Act
      result = Archive.cleanup(temp_path)

      # Assert
      assert :ok = result
      refute File.exists?(temp_path)
    end

    test "returns ok when directory does not exist" do
      # Arrange
      non_existent_path = "test/tmp/nonexistent_temp_dir"

      # Act
      result = Archive.cleanup(non_existent_path)

      # Assert
      assert :ok = result
    end

    test "removes nested directory structure" do
      # Arrange
      FixtureHelper.create_minimal_docx(@fixture_path)
      {:ok, temp_path} = Archive.extract(@fixture_path)
      assert File.exists?(Path.join(temp_path, "word/document.xml"))

      # Act
      result = Archive.cleanup(temp_path)

      # Assert
      assert :ok = result
      refute File.exists?(temp_path)
      refute File.exists?(Path.join(temp_path, "word"))
    end
  end

  describe "round-trip operations" do
    test "extract and recreate preserves document content" do
      # Arrange
      FixtureHelper.create_minimal_docx(@fixture_path)

      # Act - Extract specific files and recreate
      {:ok, content_types} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "[Content_Types].xml")
      {:ok, document} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "word/document.xml")
      {:ok, rels} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "_rels/.rels")
      {:ok, doc_rels} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "word/_rels/document.xml.rels")

      file_map = %{
        "[Content_Types].xml" => content_types,
        "word/document.xml" => document,
        "_rels/.rels" => rels,
        "word/_rels/document.xml.rels" => doc_rels
      }

      Archive.create(file_map, @output_path)

      # Assert - verify recreated archive has same content
      {:ok, new_document} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")
      {:ok, new_content_types} = OotemplTestHelpers.extract_file_for_test(@output_path, "[Content_Types].xml")

      assert new_document == document
      assert new_content_types == content_types
    end

    test "modifying and recreating produces valid archive" do
      # Arrange
      FixtureHelper.create_minimal_docx(@fixture_path)
      {:ok, original_content} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "word/document.xml")

      # Act - Modify content
      modified_content = String.replace(original_content, "Hello, World!", "Modified Text")

      {:ok, content_types} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "[Content_Types].xml")
      {:ok, rels} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "_rels/.rels")
      {:ok, doc_rels} = OotemplTestHelpers.extract_file_for_test(@fixture_path, "word/_rels/document.xml.rels")

      file_map = %{
        "[Content_Types].xml" => content_types,
        "word/document.xml" => modified_content,
        "_rels/.rels" => rels,
        "word/_rels/document.xml.rels" => doc_rels
      }

      Archive.create(file_map, @output_path)

      # Assert
      {:ok, result_content} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")
      assert result_content == modified_content
      assert result_content =~ "Modified Text"
      refute result_content =~ "Hello, World!"
    end
  end
end
