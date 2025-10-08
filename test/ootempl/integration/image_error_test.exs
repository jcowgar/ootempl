defmodule Ootempl.Integration.ImageErrorTest do
  @moduledoc """
  Integration tests for image error handling through Ootempl.render/3.

  Tests various image-related error conditions to ensure proper error
  reporting when image replacements fail.
  """

  use ExUnit.Case

  @fixtures_dir "test/fixtures"
  @temp_error_dir Path.join(@fixtures_dir, "image_errors")

  setup do
    # Create temp directory for error test files
    File.mkdir_p!(@temp_error_dir)

    on_exit(fn ->
      File.rm_rf(@temp_error_dir)
    end)

    :ok
  end

  describe "image error handling" do
    test "returns error when image path not provided in data" do
      # Arrange - create template with image placeholder
      template_path = Path.join(@temp_error_dir, "missing_data.docx")
      output_path = Path.join(@temp_error_dir, "missing_data_output.docx")

      create_image_placeholder_docx(template_path, "logo")

      # Act - render without providing image data
      result = Ootempl.render(template_path, %{}, output_path)

      # Assert
      assert {:error, image_error} = result

      assert %Ootempl.ImageError{
               reason: :image_not_found_in_data,
               placeholder_name: "logo",
               image_path: nil
             } = image_error

      assert image_error.message =~ "has no corresponding data key 'logo'"
    end

    test "returns error when image file does not exist" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "file_not_found.docx")
      output_path = Path.join(@temp_error_dir, "file_not_found_output.docx")

      create_image_placeholder_docx(template_path, "photo")

      non_existent_path = "/path/to/nonexistent/image.png"
      data = %{"photo" => non_existent_path}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, image_error} = result

      assert %Ootempl.ImageError{
               reason: :file_not_found,
               placeholder_name: "photo",
               image_path: ^non_existent_path
             } = image_error

      assert image_error.message =~ "Image file not found"
    end

    test "returns error when image file is not readable" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "unreadable.docx")
      output_path = Path.join(@temp_error_dir, "unreadable_output.docx")

      # Create an unreadable file (no read permissions)
      unreadable_path = Path.join(@temp_error_dir, "unreadable.png")
      File.write!(unreadable_path, "image data")
      File.chmod!(unreadable_path, 0o000)

      create_image_placeholder_docx(template_path, "badge")
      data = %{"badge" => unreadable_path}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Cleanup - restore permissions so cleanup can delete the file
      File.chmod!(unreadable_path, 0o644)

      # Assert
      assert {:error, image_error} = result

      assert %Ootempl.ImageError{
               reason: :file_not_readable,
               placeholder_name: "badge"
             } = image_error

      assert image_error.message =~ "cannot be read"
    end

    test "returns error for unsupported image format" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "unsupported_format.docx")
      output_path = Path.join(@temp_error_dir, "unsupported_format_output.docx")

      # Create a .bmp file (unsupported format)
      bmp_path = Path.join(@temp_error_dir, "test.bmp")
      File.write!(bmp_path, "fake bmp data")

      create_image_placeholder_docx(template_path, "icon")
      data = %{"icon" => bmp_path}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, image_error} = result

      assert %Ootempl.ImageError{
               reason: :unsupported_format,
               placeholder_name: "icon",
               image_path: ^bmp_path
             } = image_error

      assert image_error.message =~ "Unsupported image format"
      assert image_error.message =~ "only PNG, JPEG, GIF supported"
    end

    test "returns error when image file is corrupt and dimensions cannot be read" do
      # Arrange
      template_path = Path.join(@temp_error_dir, "corrupt_image.docx")
      output_path = Path.join(@temp_error_dir, "corrupt_image_output.docx")

      # Create a corrupt PNG file (invalid data but .png extension)
      corrupt_path = Path.join(@temp_error_dir, "corrupt.png")
      File.write!(corrupt_path, "this is not valid PNG data")

      create_image_placeholder_docx(template_path, "avatar")
      data = %{"avatar" => corrupt_path}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - corrupt PNG will return :invalid_image_format or :cannot_read_dimensions
      assert {:error, image_error} = result

      assert %Ootempl.ImageError{
               placeholder_name: "avatar",
               image_path: ^corrupt_path
             } = image_error

      # The specific reason may vary, but it should be an image processing error
      assert image_error.reason in [:invalid_image_format, :cannot_read_dimensions]
      assert image_error.message =~ "avatar"
    end
  end

  # Helper functions

  defp create_image_placeholder_docx(path, placeholder_name) do
    # Create minimal .docx with an image placeholder
    # Image placeholders use the format @image:name@
    document_xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <w:body>
        <w:p>
          <w:r>
            <w:drawing>
              <wp:inline>
                <wp:docPr name="Picture 1" descr="@image:#{placeholder_name}@"/>
                <a:graphic>
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic>
                      <pic:nvPicPr>
                        <pic:cNvPr id="1" name="Picture 1"/>
                      </pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="rId5"/>
                      </pic:blipFill>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """

    files = %{
      "word/document.xml" => document_xml,
      "[Content_Types].xml" => minimal_content_types_xml(),
      "_rels/.rels" => minimal_rels_xml(),
      "word/_rels/document.xml.rels" => minimal_document_rels_xml()
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
      <Default Extension="png" ContentType="image/png"/>
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

  defp minimal_document_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
    </Relationships>
    """
  end
end
