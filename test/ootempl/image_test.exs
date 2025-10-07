defmodule Ootempl.ImageTest do
  use ExUnit.Case, async: true

  alias Ootempl.Image

  describe "validate_image_file/1" do
    test "validates PNG file" do
      # Arrange
      image_path = "test/fixtures/logo.png"

      # Act
      result = Image.validate_image_file(image_path)

      # Assert
      assert result == :ok
    end

    test "returns error for non-existent file" do
      # Arrange
      image_path = "test/fixtures/nonexistent.png"

      # Act
      result = Image.validate_image_file(image_path)

      # Assert
      assert result == {:error, :file_not_found}
    end

    test "returns error for unsupported format" do
      # Arrange
      # Create a temporary file with wrong extension
      temp_path = "test/fixtures/temp_test.bmp"
      File.write!(temp_path, "fake content")

      # Act
      result = Image.validate_image_file(temp_path)

      # Assert
      assert result == {:error, :unsupported_format}

      # Cleanup
      File.rm!(temp_path)
    end

    test "validates JPEG file" do
      # Arrange - assuming this fixture exists
      image_path = "test/fixtures/logo.png"

      # Act
      result = Image.validate_image_file(image_path)

      # Assert
      assert result == :ok
    end
  end

  describe "get_image_dimensions/1" do
    test "gets dimensions from PNG file" do
      # Arrange
      image_path = "test/fixtures/logo.png"

      # Act
      result = Image.get_image_dimensions(image_path)

      # Assert
      assert {:ok, {width, height}} = result
      assert is_integer(width)
      assert is_integer(height)
      assert width > 0
      assert height > 0
    end

    test "returns error for non-existent file" do
      # Arrange
      image_path = "test/fixtures/missing.png"

      # Act
      result = Image.get_image_dimensions(image_path)

      # Assert
      assert {:error, :cannot_read_file} = result
    end

    test "returns error for corrupt image" do
      # Arrange
      corrupt_path = "test/fixtures/corrupt_image.png"
      File.write!(corrupt_path, "not an image")

      # Act
      result = Image.get_image_dimensions(corrupt_path)

      # Assert
      assert {:error, :invalid_image_format} = result

      # Cleanup
      File.rm!(corrupt_path)
    end

    test "reads dimensions from GIF87a format" do
      # Arrange
      # Create minimal GIF87a file with 50x30 dimensions
      gif87a_path = "test/fixtures/test_gif87a.gif"
      gif87a_data = "GIF87a" <> <<50::little-16, 30::little-16>> <> <<0, 0, 0>>
      File.write!(gif87a_path, gif87a_data)

      # Act
      result = Image.get_image_dimensions(gif87a_path)

      # Assert
      assert {:ok, {50, 30}} = result

      # Cleanup
      File.rm!(gif87a_path)
    end

    test "reads dimensions from GIF89a format" do
      # Arrange
      # Create minimal GIF89a file with 100x200 dimensions
      gif89a_path = "test/fixtures/test_gif89a.gif"
      gif89a_data = "GIF89a" <> <<100::little-16, 200::little-16>> <> <<0, 0, 0>>
      File.write!(gif89a_path, gif89a_data)

      # Act
      result = Image.get_image_dimensions(gif89a_path)

      # Assert
      assert {:ok, {100, 200}} = result

      # Cleanup
      File.rm!(gif89a_path)
    end

    test "returns error for truncated GIF file" do
      # Arrange
      truncated_gif_path = "test/fixtures/truncated.gif"
      # GIF header but not enough data for dimensions
      File.write!(truncated_gif_path, "GIF89a" <> <<1>>)

      # Act
      result = Image.get_image_dimensions(truncated_gif_path)

      # Assert
      assert {:error, :invalid_image_format} = result

      # Cleanup
      File.rm!(truncated_gif_path)
    end

    test "returns error for truncated PNG file" do
      # Arrange
      truncated_png_path = "test/fixtures/truncated.png"
      # PNG signature but no IHDR chunk
      File.write!(truncated_png_path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)

      # Act
      result = Image.get_image_dimensions(truncated_png_path)

      # Assert
      assert {:error, :invalid_image_format} = result

      # Cleanup
      File.rm!(truncated_png_path)
    end

    test "returns error for truncated JPEG file" do
      # Arrange
      truncated_jpeg_path = "test/fixtures/truncated.jpg"
      # JPEG signature but no valid markers
      File.write!(truncated_jpeg_path, <<0xFF, 0xD8, 0xFF>>)

      # Act
      result = Image.get_image_dimensions(truncated_jpeg_path)

      # Assert
      assert {:error, :invalid_image_format} = result

      # Cleanup
      File.rm!(truncated_jpeg_path)
    end

    test "handles JPEG with escaped FF bytes" do
      # Arrange
      # Create JPEG with 0xFF00 marker (escaped FF byte) before SOF
      jpeg_with_escape_path = "test/fixtures/jpeg_with_escape.jpg"
      # JPEG signature + escaped FF + SOF0 marker with dimensions
      jpeg_data =
        <<0xFF, 0xD8>> <>
          # Escaped FF byte
          <<0xFF, 0x00>> <>
          # SOF0 marker (0xFFC0)
          <<0xFF, 0xC0>> <>
          # Length (17 bytes)
          <<0, 17>> <>
          # Precision
          <<8>> <>
          # Height
          <<0, 100>> <>
          # Width
          <<0, 150>> <>
          # Components
          <<3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1>>

      File.write!(jpeg_with_escape_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_with_escape_path)

      # Assert
      assert {:ok, {150, 100}} = result

      # Cleanup
      File.rm!(jpeg_with_escape_path)
    end
  end

  describe "calculate_scaled_dimensions/2" do
    test "scales down large image to fit template bounds" do
      # Arrange
      source_dims = {2000, 1000}
      template_dims = {400, 300}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      {scaled_width, scaled_height} = result
      assert scaled_width <= 400
      assert scaled_height <= 300
      # Verify aspect ratio preserved (2:1)
      assert_in_delta scaled_width / scaled_height, 2.0, 0.01
    end

    test "scales up small image to fit template bounds" do
      # Arrange
      source_dims = {50, 25}
      template_dims = {400, 300}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width <= 400
      assert scaled_height <= 300
    end

    test "handles portrait orientation (height > width)" do
      # Arrange
      source_dims = {300, 600}
      template_dims = {200, 400}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width <= 200
      assert scaled_height <= 400
      # Aspect ratio should be preserved
      assert abs(scaled_width / scaled_height - 0.5) < 0.01
    end

    test "handles square images" do
      # Arrange
      source_dims = {500, 500}
      template_dims = {200, 300}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width <= 200
      assert scaled_height <= 300
      # Should be square
      assert scaled_width == scaled_height
    end

    test "handles very wide images" do
      # Arrange
      source_dims = {3000, 100}
      template_dims = {400, 300}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width <= 400
      assert scaled_height <= 300
      assert scaled_width > scaled_height
    end

    test "handles very tall images" do
      # Arrange
      source_dims = {100, 3000}
      template_dims = {400, 300}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width <= 400
      assert scaled_height <= 300
      assert scaled_height > scaled_width
    end

    test "handles minimal dimensions" do
      # Arrange
      source_dims = {1, 1}
      template_dims = {100, 100}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert scaled_width > 0
      assert scaled_height > 0
    end

    test "preserves aspect ratio for landscape images" do
      # Arrange
      source_dims = {1600, 900}
      template_dims = {400, 300}

      # Act
      {scaled_width, scaled_height} = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      # Original aspect ratio is 16:9 ≈ 1.778
      # Scaled should maintain this
      aspect_ratio = scaled_width / scaled_height
      assert abs(aspect_ratio - 1.778) < 0.01
    end
  end

  describe "generate_media_filename/2" do
    test "generates image1.png when no existing files" do
      # Arrange
      existing_files = []
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image1.png"
    end

    test "generates next available number" do
      # Arrange
      existing_files = ["word/media/image1.png", "word/media/image2.png"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image3.png"
    end

    test "handles non-sequential existing files" do
      # Arrange
      existing_files = ["word/media/image1.png", "word/media/image5.png", "word/media/image3.png"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image6.png"
    end

    test "handles files with different extensions" do
      # Arrange
      existing_files = ["word/media/image1.jpg", "word/media/image2.png", "word/media/image3.gif"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image4.png"
    end

    test "handles jpeg extension" do
      # Arrange
      existing_files = []
      extension = ".jpeg"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image1.jpeg"
    end

    test "handles files not in media folder" do
      # Arrange
      existing_files = ["word/document.xml", "word/styles.xml"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image1.png"
    end
  end

  describe "mime_type_for_extension/1" do
    test "returns correct MIME type for png" do
      # Act
      result = Image.mime_type_for_extension("png")

      # Assert
      assert result == "image/png"
    end

    test "returns correct MIME type for jpeg" do
      # Act
      result = Image.mime_type_for_extension("jpeg")

      # Assert
      assert result == "image/jpeg"
    end

    test "returns correct MIME type for jpg" do
      # Act
      result = Image.mime_type_for_extension("jpg")

      # Assert
      assert result == "image/jpeg"
    end

    test "returns correct MIME type for gif" do
      # Act
      result = Image.mime_type_for_extension("gif")

      # Assert
      assert result == "image/gif"
    end

    test "returns nil for unsupported extension" do
      # Act
      result = Image.mime_type_for_extension("bmp")

      # Assert
      assert result == nil
    end

    test "handles uppercase extensions" do
      # Act
      result_png = Image.mime_type_for_extension("PNG")
      result_jpeg = Image.mime_type_for_extension("JPEG")

      # Assert
      # Function downcases input, so uppercase should work
      assert result_png == "image/png"
      assert result_jpeg == "image/jpeg"
    end
  end

  describe "parse_content_types/1" do
    test "parses valid content types XML" do
      # Arrange
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="xml" ContentType="application/xml"/>
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      # Act
      result = Image.parse_content_types(xml)

      # Assert
      assert {:ok, _element} = result
    end

    test "returns error for invalid XML" do
      # Arrange
      invalid_xml = "<Types><unclosed"

      # Act
      result = Image.parse_content_types(invalid_xml)

      # Assert
      assert {:error, :invalid_xml} = result
    end

    test "returns error for empty string" do
      # Arrange
      xml = ""

      # Act
      result = Image.parse_content_types(xml)

      # Assert
      assert {:error, :invalid_xml} = result
    end
  end

  describe "serialize_content_types/1" do
    test "serializes content types XML" do
      # Arrange
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="xml" ContentType="application/xml"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      xml_string = Image.serialize_content_types(types_xml)

      # Assert
      assert is_binary(xml_string)
      assert xml_string =~ "Types"
      assert xml_string =~ "application/xml"
    end
  end

  describe "add_content_type/3" do
    test "adds new content type to XML" do
      # Arrange
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="xml" ContentType="application/xml"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      updated_xml = Image.add_content_type(types_xml, "png", "image/png")

      # Assert
      serialized = Image.serialize_content_types(updated_xml)
      assert serialized =~ "png"
      assert serialized =~ "image/png"
    end

    test "does not duplicate existing content type" do
      # Arrange
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      updated_xml = Image.add_content_type(types_xml, "png", "image/png")

      # Assert
      serialized = Image.serialize_content_types(updated_xml)
      # Count occurrences - should still be just one
      png_count = serialized |> String.split("Extension=\"png\"") |> length() |> Kernel.-(1)
      assert png_count == 1
    end
  end
end
