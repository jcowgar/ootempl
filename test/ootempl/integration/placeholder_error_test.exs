defmodule Ootempl.Integration.PlaceholderErrorTest do
  @moduledoc """
  Integration tests for placeholder error handling through Ootempl.render/3.

  Tests various placeholder-related error conditions to ensure proper error
  reporting when placeholder resolution fails.
  """

  use ExUnit.Case

  @fixtures_dir "test/fixtures"
  @temp_error_dir Path.join(@fixtures_dir, "placeholder_errors")

  setup do
    # Create temp directory for error test files
    File.mkdir_p!(@temp_error_dir)

    on_exit(fn ->
      File.rm_rf(@temp_error_dir)
    end)

    :ok
  end

  describe "placeholder error handling" do
    test "returns error when single placeholder cannot be resolved" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "single_missing.docx")
      output_path = Path.join(@temp_error_dir, "single_missing_output.docx")

      create_placeholder_docx(template_path, "@name@")

      # Act - render without providing data
      result = Ootempl.render(template_path, %{}, output_path)

      # Assert
      assert {:error,
              %Ootempl.PlaceholderError{
                placeholders: [%{placeholder: "@name@"}]
              } = placeholder_error} = result

      # Should use singular message for single placeholder
      assert placeholder_error.message =~ "Placeholder @name@ could not be resolved"
      refute placeholder_error.message =~ "placeholders"
    end

    test "returns error when multiple placeholders cannot be resolved" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "multiple_missing.docx")
      output_path = Path.join(@temp_error_dir, "multiple_missing_output.docx")

      create_placeholder_docx(template_path, "@first_name@ @last_name@ @email@")

      # Act - render without providing data
      result = Ootempl.render(template_path, %{}, output_path)

      # Assert
      assert {:error, %Ootempl.PlaceholderError{} = placeholder_error} = result

      # Should use plural message for multiple placeholders
      assert placeholder_error.message =~ "3 placeholders could not be resolved"
      assert placeholder_error.message =~ "first: @first_name@"
      assert length(placeholder_error.placeholders) == 3
    end

    test "returns error with path_not_found reason" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "path_not_found.docx")
      output_path = Path.join(@temp_error_dir, "path_not_found_output.docx")

      create_placeholder_docx(template_path, "@person.name@")

      # Act - provide data but not the nested path
      result = Ootempl.render(template_path, %{"other" => "data"}, output_path)

      # Assert
      assert {:error,
              %Ootempl.PlaceholderError{
                placeholders: [%{placeholder: "@person.name@", reason: {:path_not_found, ["person", "name"]}}]
              }} = result
    end

    test "returns error when accessing index in non-list value" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "not_a_list.docx")
      output_path = Path.join(@temp_error_dir, "not_a_list_output.docx")

      create_placeholder_docx(template_path, "@items.0@")

      # Act - provide string instead of list
      result = Ootempl.render(template_path, %{"items" => "not a list"}, output_path)

      # Assert
      assert {:error,
              %Ootempl.PlaceholderError{
                placeholders: [%{placeholder: "@items.0@"}]
              }} = result
    end

    test "returns error when list index out of bounds" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "index_out_of_bounds.docx")
      output_path = Path.join(@temp_error_dir, "index_out_of_bounds_output.docx")

      create_placeholder_docx(template_path, "@items.5@")

      # Act - provide list with only 2 items
      result = Ootempl.render(template_path, %{"items" => ["a", "b"]}, output_path)

      # Assert
      assert {:error,
              %Ootempl.PlaceholderError{
                placeholders: [%{placeholder: "@items.5@"}]
              }} = result
    end

    test "returns error when value is nil" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "nil_value.docx")
      output_path = Path.join(@temp_error_dir, "nil_value_output.docx")

      create_placeholder_docx(template_path, "@name@")

      # Act - provide nil value
      result = Ootempl.render(template_path, %{"name" => nil}, output_path)

      # Assert
      assert {:error,
              %Ootempl.PlaceholderError{
                placeholders: [%{placeholder: "@name@", reason: :nil_value}]
              }} = result
    end
  end

  # Helper functions

  defp create_placeholder_docx(path, placeholder_text) do
    document_xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>#{placeholder_text}</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """

    files = %{
      "word/document.xml" => document_xml,
      "[Content_Types].xml" => minimal_content_types_xml(),
      "_rels/.rels" => minimal_rels_xml()
    }

    create_zip(path, files)
  end

  defp create_zip(path, files) do
    file_list =
      Enum.map(files, fn {internal_path, content} ->
        {String.to_charlist(internal_path), content}
      end)

    {:ok, _} = :zip.create(String.to_charlist(path), file_list)
    :ok
  end

  defp minimal_content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """
  end

  defp minimal_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """
  end
end
