defmodule Ootempl.ImageTest do
  use ExUnit.Case, async: true

  import Record, only: [defrecord: 2, extract: 2]

  alias Ootempl.Image

  # Extract XML element records from xmerl
  defrecord :xmlElement, extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  defrecord :xmlText, extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")

  @test_png_path "test/fixtures/images/test.png"
  @test_jpg_path "test/fixtures/images/test.jpg"
  @test_gif_path "test/fixtures/images/test.gif"

  describe "parse_image_marker/1" do
    test "parses valid image marker" do
      # Arrange
      alt_text = "@image:logo@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == {:ok, "logo"}
    end

    test "parses image marker with underscores" do
      # Arrange
      alt_text = "@image:company_logo@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == {:ok, "company_logo"}
    end

    test "parses image marker with hyphens" do
      # Arrange
      alt_text = "@image:company-logo@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == {:ok, "company-logo"}
    end

    test "parses image marker with numbers" do
      # Arrange
      alt_text = "@image:logo123@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == {:ok, "logo123"}
    end

    test "returns error for non-marker text" do
      # Arrange
      alt_text = "Regular alt text"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end

    test "returns error for malformed marker missing closing @" do
      # Arrange
      alt_text = "@image:logo"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end

    test "returns error for malformed marker missing opening @" do
      # Arrange
      alt_text = "image:logo@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end

    test "returns error for marker with spaces" do
      # Arrange
      alt_text = "@image:my logo@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end

    test "returns error for marker with special characters" do
      # Arrange
      alt_text = "@image:logo!@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end

    test "returns error for empty marker" do
      # Arrange
      alt_text = "@image:@"

      # Act
      result = Image.parse_image_marker(alt_text)

      # Assert
      assert result == :error
    end
  end

  describe "supported_format?/1" do
    test "returns true for .png extension" do
      # Arrange
      path = "/path/to/image.png"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == true
    end

    test "returns true for .PNG extension (uppercase)" do
      # Arrange
      path = "/path/to/image.PNG"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == true
    end

    test "returns true for .jpg extension" do
      # Arrange
      path = "/path/to/image.jpg"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == true
    end

    test "returns true for .jpeg extension" do
      # Arrange
      path = "/path/to/image.jpeg"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == true
    end

    test "returns true for .gif extension" do
      # Arrange
      path = "/path/to/image.gif"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == true
    end

    test "returns false for .bmp extension" do
      # Arrange
      path = "/path/to/image.bmp"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == false
    end

    test "returns false for .tiff extension" do
      # Arrange
      path = "/path/to/image.tiff"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == false
    end

    test "returns false for .svg extension" do
      # Arrange
      path = "/path/to/image.svg"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == false
    end

    test "returns false for no extension" do
      # Arrange
      path = "/path/to/image"

      # Act
      result = Image.supported_format?(path)

      # Assert
      assert result == false
    end
  end

  describe "validate_image_file/1" do
    test "returns :ok for valid PNG file" do
      # Arrange
      path = @test_png_path

      # Act
      result = Image.validate_image_file(path)

      # Assert
      assert result == :ok
    end

    test "returns :ok for valid JPEG file" do
      # Arrange
      path = @test_jpg_path

      # Act
      result = Image.validate_image_file(path)

      # Assert
      assert result == :ok
    end

    test "returns :ok for valid GIF file" do
      # Arrange
      path = @test_gif_path

      # Act
      result = Image.validate_image_file(path)

      # Assert
      assert result == :ok
    end

    test "returns error for non-existent file" do
      # Arrange
      path = "/path/to/nonexistent.png"

      # Act
      result = Image.validate_image_file(path)

      # Assert
      assert result == {:error, :file_not_found}
    end

    test "returns error for unsupported format" do
      # Arrange
      # Create a temporary .bmp file
      bmp_path = "test/fixtures/images/test.bmp"
      File.write!(bmp_path, "fake bmp data")

      # Act
      result = Image.validate_image_file(bmp_path)

      # Assert
      assert result == {:error, :unsupported_format}

      # Cleanup
      File.rm!(bmp_path)
    end

    test "returns error for directory path" do
      # Arrange
      path = "test/fixtures/images"

      # Act
      result = Image.validate_image_file(path)

      # Assert
      assert result == {:error, :unsupported_format}
    end
  end

  describe "get_image_dimensions/1" do
    test "reads dimensions from PNG file" do
      # Arrange
      path = @test_png_path

      # Act
      result = Image.get_image_dimensions(path)

      # Assert
      assert result == {:ok, {800, 600}}
    end

    test "reads dimensions from JPEG file" do
      # Arrange
      path = @test_jpg_path

      # Act
      result = Image.get_image_dimensions(path)

      # Assert
      assert result == {:ok, {640, 500}}
    end

    test "reads dimensions from GIF file" do
      # Arrange
      path = @test_gif_path

      # Act
      result = Image.get_image_dimensions(path)

      # Assert
      assert result == {:ok, {320, 240}}
    end

    test "returns error for non-existent file" do
      # Arrange
      path = "/path/to/nonexistent.png"

      # Act
      result = Image.get_image_dimensions(path)

      # Assert
      assert result == {:error, :cannot_read_file}
    end

    test "returns error for invalid PNG file" do
      # Arrange
      invalid_path = "test/fixtures/images/invalid.png"
      File.write!(invalid_path, "not a real png")

      # Act
      result = Image.get_image_dimensions(invalid_path)

      # Assert
      assert result == {:error, :invalid_image_format}

      # Cleanup
      File.rm!(invalid_path)
    end

    test "returns error for invalid JPEG file" do
      # Arrange
      invalid_path = "test/fixtures/images/invalid.jpg"
      File.write!(invalid_path, "not a real jpeg")

      # Act
      result = Image.get_image_dimensions(invalid_path)

      # Assert
      assert result == {:error, :invalid_image_format}

      # Cleanup
      File.rm!(invalid_path)
    end

    test "returns error for invalid GIF file" do
      # Arrange
      invalid_path = "test/fixtures/images/invalid.gif"
      File.write!(invalid_path, "not a real gif")

      # Act
      result = Image.get_image_dimensions(invalid_path)

      # Assert
      assert result == {:error, :invalid_image_format}

      # Cleanup
      File.rm!(invalid_path)
    end

    test "reads dimensions from GIF87a file" do
      # Arrange
      gif87a_path = "test/fixtures/images/test87a.gif"

      gif87a_data = <<
        # GIF header
        # "GIF87a"
        0x47,
        0x49,
        0x46,
        0x38,
        0x37,
        0x61,
        # Width: 512 (little-endian)
        0x00,
        0x02,
        # Height: 256 (little-endian)
        0x00,
        0x01,
        # Global color table flag
        0x80,
        # Background color index
        0x00,
        # Pixel aspect ratio
        0x00,
        # Global color table (2 colors)
        # Black
        0x00,
        0x00,
        0x00,
        # White
        0xFF,
        0xFF,
        0xFF,
        # Trailer
        0x3B
      >>

      File.write!(gif87a_path, gif87a_data)

      # Act
      result = Image.get_image_dimensions(gif87a_path)

      # Assert
      assert result == {:ok, {512, 256}}

      # Cleanup
      File.rm!(gif87a_path)
    end

    test "handles unsupported format in get_image_dimensions" do
      # Arrange
      bmp_path = "test/fixtures/images/test.bmp"
      File.write!(bmp_path, "fake bmp")

      # Act
      result = Image.get_image_dimensions(bmp_path)

      # Assert
      assert result == {:error, :unsupported_format}

      # Cleanup
      File.rm!(bmp_path)
    end

    test "handles JPEG with truncated data" do
      # Arrange
      truncated_path = "test/fixtures/images/truncated.jpg"
      # JPEG with valid signature but truncated SOF
      truncated_data = <<0xFF, 0xD8, 0xFF, 0xC0, 0x00>>
      File.write!(truncated_path, truncated_data)

      # Act
      result = Image.get_image_dimensions(truncated_path)

      # Assert
      assert result == {:error, :invalid_image_format}

      # Cleanup
      File.rm!(truncated_path)
    end

    test "handles JPEG with 0xFF00 marker" do
      # Arrange
      jpeg_path = "test/fixtures/images/test_ff00.jpg"

      jpeg_data = <<
        # JPEG SOI
        0xFF,
        0xD8,
        # 0xFF00 marker (escaped 0xFF)
        0xFF,
        0x00,
        # SOF0
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        # Height: 100
        0x00,
        0x64,
        # Width: 200
        0x00,
        0xC8,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        # EOI
        0xFF,
        0xD9
      >>

      File.write!(jpeg_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_path)

      # Assert
      assert result == {:ok, {200, 100}}

      # Cleanup
      File.rm!(jpeg_path)
    end
  end

  describe "find_placeholder_images/1" do
    test "finds image with valid placeholder marker" do
      # Arrange
      xml = build_drawing_xml("@image:logo@", "rId5", {914_400, 914_400})

      # Act
      result = Image.find_placeholder_images(xml)

      # Assert
      assert [placeholder] = result
      assert placeholder.placeholder_name == "logo"
      assert placeholder.alt_text == "@image:logo@"
      assert placeholder.relationship_id == "rId5"
      assert placeholder.template_dimensions == {914_400, 914_400}
    end

    test "finds multiple placeholder images" do
      # Arrange
      xml =
        build_document_with_multiple_drawings([
          {"@image:logo@", "rId5", {914_400, 914_400}},
          {"@image:signature@", "rId6", {457_200, 228_600}}
        ])

      # Act
      result = Image.find_placeholder_images(xml)

      # Assert
      assert length(result) == 2
      assert Enum.any?(result, &(&1.placeholder_name == "logo"))
      assert Enum.any?(result, &(&1.placeholder_name == "signature"))
    end

    test "ignores images without placeholder markers" do
      # Arrange
      xml = build_drawing_xml("Regular alt text", "rId5", {914_400, 914_400})

      # Act
      result = Image.find_placeholder_images(xml)

      # Assert
      assert result == []
    end

    test "ignores images with empty alt text" do
      # Arrange
      xml = build_drawing_xml("", "rId5", {914_400, 914_400})

      # Act
      result = Image.find_placeholder_images(xml)

      # Assert
      assert result == []
    end

    test "returns empty list when no drawings present" do
      # Arrange
      xml = build_simple_paragraph()

      # Act
      result = Image.find_placeholder_images(xml)

      # Assert
      assert result == []
    end

    test "handles nested structure with drawings deep in tree" do
      # Arrange
      drawing = build_drawing_xml("@image:logo@", "rId5", {914_400, 914_400})
      paragraph = xmlElement(name: :"w:p", content: [drawing])
      body = xmlElement(name: :"w:body", content: [paragraph])
      document = xmlElement(name: :"w:document", content: [body])

      # Act
      result = Image.find_placeholder_images(document)

      # Assert
      assert [placeholder] = result
      assert placeholder.placeholder_name == "logo"
    end

    test "handles drawing without docPr element" do
      # Arrange
      # Build a drawing without wp:docPr
      blip =
        xmlElement(
          name: :"a:blip",
          attributes: [xmlAttribute(name: :embed, value: ~c"rId5")],
          content: []
        )

      inline = xmlElement(name: :"wp:inline", content: [blip])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert
      assert result == []
    end

    test "handles drawing without relationship ID" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:logo@")],
          content: []
        )

      # No blip element, so no relationship ID
      inline = xmlElement(name: :"wp:inline", content: [doc_pr])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert
      assert [placeholder] = result
      assert placeholder.placeholder_name == "logo"
      assert placeholder.relationship_id == nil
    end

    test "handles drawing without dimensions" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:logo@")],
          content: []
        )

      blip =
        xmlElement(
          name: :"a:blip",
          attributes: [xmlAttribute(name: :embed, value: ~c"rId5")],
          content: []
        )

      # No extent element
      inline = xmlElement(name: :"wp:inline", content: [doc_pr, blip])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert
      assert [placeholder] = result
      assert placeholder.placeholder_name == "logo"
      assert placeholder.template_dimensions == nil
    end

    test "handles drawing with malformed extent values" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:logo@")],
          content: []
        )

      extent =
        xmlElement(
          name: :"wp:extent",
          attributes: [
            xmlAttribute(name: :cx, value: ~c"invalid"),
            xmlAttribute(name: :cy, value: ~c"also_invalid")
          ],
          content: []
        )

      inline = xmlElement(name: :"wp:inline", content: [doc_pr, extent])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert
      assert [placeholder] = result
      assert placeholder.template_dimensions == nil
    end

    test "handles non-element content in XML tree" do
      # Arrange
      text = xmlText(value: ~c"Some text")
      paragraph = xmlElement(name: :"w:p", content: [text])

      # Act
      result = Image.find_placeholder_images(paragraph)

      # Assert
      assert result == []
    end

    test "handles JPEG with non-marker byte sequences" do
      # Arrange
      jpeg_path = "test/fixtures/images/test_other_bytes.jpg"

      jpeg_data = <<
        # JPEG SOI
        0xFF,
        0xD8,
        # Random non-marker bytes
        0x12,
        0x34,
        0x56,
        0x78,
        # SOF0
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        # Height: 120
        0x00,
        0x78,
        # Width: 160
        0x00,
        0xA0,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        # EOI
        0xFF,
        0xD9
      >>

      File.write!(jpeg_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_path)

      # Assert
      assert result == {:ok, {160, 120}}

      # Cleanup
      File.rm!(jpeg_path)
    end

    test "handles JPEG with progressive SOF2 marker" do
      # Arrange
      jpeg_path = "test/fixtures/images/test_sof2.jpg"

      jpeg_data = <<
        # JPEG SOI
        0xFF,
        0xD8,
        # SOF2 (progressive DCT)
        0xFF,
        0xC2,
        0x00,
        0x11,
        0x08,
        # Height: 300
        0x01,
        0x2C,
        # Width: 400
        0x01,
        0x90,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        # EOI
        0xFF,
        0xD9
      >>

      File.write!(jpeg_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_path)

      # Assert
      assert result == {:ok, {400, 300}}

      # Cleanup
      File.rm!(jpeg_path)
    end

    test "handles JPEG with marker segment to skip" do
      # Arrange
      jpeg_path = "test/fixtures/images/test_skip_marker.jpg"

      jpeg_data = <<
        # JPEG SOI
        0xFF,
        0xD8,
        # Comment marker (needs to be skipped)
        0xFF,
        0xFE,
        # Length: 6 bytes (includes length itself)
        0x00,
        0x06,
        # Comment data
        0x74,
        0x65,
        0x73,
        0x74,
        # SOF0
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        # Height: 50
        0x00,
        0x32,
        # Width: 75
        0x00,
        0x4B,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        # EOI
        0xFF,
        0xD9
      >>

      File.write!(jpeg_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_path)

      # Assert
      assert result == {:ok, {75, 50}}

      # Cleanup
      File.rm!(jpeg_path)
    end

    test "handles attribute with missing name" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:test@")],
          content: []
        )

      # Act - test get_attribute_value with non-existent attribute
      # This is tested indirectly through find_relationship_id returning nil
      inline = xmlElement(name: :"wp:inline", content: [doc_pr])
      drawing = xmlElement(name: :"w:drawing", content: [inline])
      result = Image.find_placeholder_images(drawing)

      # Assert - relationship_id should be nil since there's no blip element
      assert [placeholder] = result
      assert placeholder.relationship_id == nil
    end

    test "handles extent with only cx value" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:logo@")],
          content: []
        )

      extent =
        xmlElement(
          name: :"wp:extent",
          attributes: [xmlAttribute(name: :cx, value: ~c"914400")],
          content: []
        )

      inline = xmlElement(name: :"wp:inline", content: [doc_pr, extent])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert - should have nil dimensions since cy is missing
      assert [placeholder] = result
      assert placeholder.template_dimensions == nil
    end

    test "handles JPEG with alternative SOF markers" do
      # Arrange
      # Test SOF1 (extended sequential DCT)
      jpeg_path = "test/fixtures/images/test_sof1.jpg"

      jpeg_data = <<
        0xFF,
        0xD8,
        0xFF,
        0xC1,
        0x00,
        0x11,
        0x08,
        0x00,
        0xAA,
        0x00,
        0xBB,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        0xFF,
        0xD9
      >>

      File.write!(jpeg_path, jpeg_data)

      # Act
      result = Image.get_image_dimensions(jpeg_path)

      # Assert
      assert result == {:ok, {187, 170}}

      # Cleanup
      File.rm!(jpeg_path)
    end

    test "handles deeply nested XML with mixed content" do
      # Arrange
      # Create a deeply nested structure to test traversal
      text_node = xmlText(value: ~c"some text")

      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:deep@")],
          content: [text_node]
        )

      blip =
        xmlElement(
          name: :"a:blip",
          attributes: [xmlAttribute(name: :embed, value: ~c"rId99")],
          content: []
        )

      blip_fill = xmlElement(name: :"pic:blipFill", content: [blip])
      pic = xmlElement(name: :"pic:pic", content: [blip_fill])
      graphic_data = xmlElement(name: :"a:graphicData", content: [pic])
      graphic = xmlElement(name: :"a:graphic", content: [graphic_data])

      # Add some non-xmlElement content in the mix
      inline = xmlElement(name: :"wp:inline", content: [text_node, doc_pr, text_node, graphic])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Wrap in additional layers
      run = xmlElement(name: :"w:r", content: [drawing])
      paragraph = xmlElement(name: :"w:p", content: [text_node, run])

      # Act
      result = Image.find_placeholder_images(paragraph)

      # Assert
      assert [placeholder] = result
      assert placeholder.placeholder_name == "deep"
      assert placeholder.relationship_id == "rId99"
    end

    test "handles extent with partially valid dimensions" do
      # Arrange
      doc_pr =
        xmlElement(
          name: :"wp:docPr",
          attributes: [xmlAttribute(name: :descr, value: ~c"@image:partial@")],
          content: []
        )

      # Only cx is valid number, cy is not
      extent =
        xmlElement(
          name: :"wp:extent",
          attributes: [
            xmlAttribute(name: :cx, value: ~c"100"),
            xmlAttribute(name: :cy, value: ~c"not_a_number")
          ],
          content: []
        )

      inline = xmlElement(name: :"wp:inline", content: [doc_pr, extent])
      drawing = xmlElement(name: :"w:drawing", content: [inline])

      # Act
      result = Image.find_placeholder_images(drawing)

      # Assert
      assert [placeholder] = result
      assert placeholder.template_dimensions == nil
    end
  end

  # Helper functions to build test XML structures

  defp build_drawing_xml(alt_text, relationship_id, {width, height}) do
    # Build a:blip element with r:embed attribute
    blip =
      xmlElement(
        name: :"a:blip",
        attributes: [
          xmlAttribute(name: :embed, value: to_charlist(relationship_id))
        ],
        content: []
      )

    # Build wp:extent element with cx and cy attributes
    extent =
      xmlElement(
        name: :"wp:extent",
        attributes: [
          xmlAttribute(name: :cx, value: to_charlist("#{width}")),
          xmlAttribute(name: :cy, value: to_charlist("#{height}"))
        ],
        content: []
      )

    # Build wp:docPr element with descr attribute (alt text)
    doc_pr =
      xmlElement(
        name: :"wp:docPr",
        attributes: [
          xmlAttribute(name: :descr, value: to_charlist(alt_text))
        ],
        content: []
      )

    # Build nested structure: blipFill > blip
    blip_fill =
      xmlElement(
        name: :"pic:blipFill",
        content: [blip]
      )

    # Build nested structure: pic > blipFill
    pic =
      xmlElement(
        name: :"pic:pic",
        content: [blip_fill]
      )

    # Build nested structure: graphicData > pic
    graphic_data =
      xmlElement(
        name: :"a:graphicData",
        content: [pic]
      )

    # Build nested structure: graphic > graphicData
    graphic =
      xmlElement(
        name: :"a:graphic",
        content: [graphic_data]
      )

    # Build wp:inline with docPr, extent, and graphic
    inline =
      xmlElement(
        name: :"wp:inline",
        content: [doc_pr, extent, graphic]
      )

    # Build w:drawing containing inline
    xmlElement(
      name: :"w:drawing",
      content: [inline]
    )
  end

  defp build_document_with_multiple_drawings(drawings_specs) do
    drawings =
      Enum.map(drawings_specs, fn {alt_text, rel_id, dimensions} ->
        build_drawing_xml(alt_text, rel_id, dimensions)
      end)

    paragraphs =
      Enum.map(drawings, fn drawing ->
        xmlElement(name: :"w:p", content: [drawing])
      end)

    xmlElement(name: :"w:body", content: paragraphs)
  end

  defp build_simple_paragraph do
    text = xmlText(value: ~c"Simple text")
    run = xmlElement(name: :"w:r", content: [text])
    xmlElement(name: :"w:p", content: [run])
  end

  describe "generate_media_filename/2" do
    test "generates first filename when list is empty" do
      # Arrange
      existing_files = []
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image1.png"
    end

    test "generates next sequential filename" do
      # Arrange
      existing_files = ["image1.png", "image2.jpg"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image3.png"
    end

    test "handles non-sequential existing files" do
      # Arrange
      existing_files = ["image1.png", "image5.jpg", "image3.gif"]
      extension = ".jpeg"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image6.jpeg"
    end

    test "handles files with different extensions" do
      # Arrange
      existing_files = ["image1.png", "image2.jpg", "image3.gif"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image4.png"
    end

    test "handles mixed filename formats" do
      # Arrange
      existing_files = ["image1.png", "other_file.jpg", "image2.gif"]
      extension = ".png"

      # Act
      result = Image.generate_media_filename(existing_files, extension)

      # Assert
      assert result == "image3.png"
    end
  end

  describe "calculate_scaled_dimensions/2" do
    test "scales down when source is larger than template" do
      # Arrange
      source_dims = {800, 600}
      template_dims = {400, 400}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {400.0, 300.0}
    end

    test "scales up when source is smaller than template" do
      # Arrange
      source_dims = {100, 100}
      template_dims = {200, 200}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {200.0, 200.0}
    end

    test "preserves aspect ratio for rectangular to square" do
      # Arrange
      source_dims = {200, 100}
      template_dims = {100, 100}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {100.0, 50.0}
    end

    test "preserves aspect ratio for square to rectangular" do
      # Arrange
      source_dims = {100, 100}
      template_dims = {200, 100}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {100.0, 100.0}
    end

    test "handles same dimensions" do
      # Arrange
      source_dims = {100, 100}
      template_dims = {100, 100}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {100.0, 100.0}
    end

    test "handles very different aspect ratios" do
      # Arrange
      source_dims = {400, 100}
      template_dims = {100, 100}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {100.0, 25.0}
    end

    test "handles float dimensions" do
      # Arrange
      source_dims = {100.5, 50.5}
      template_dims = {50.0, 50.0}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert_in_delta elem(result, 0), 50.0, 0.01
      assert_in_delta elem(result, 1), 25.12, 0.01
    end

    test "handles EMU dimensions (English Metric Units)" do
      # Arrange
      # 2 inches = 1,828,800 EMUs
      source_dims = {1_828_800, 1_828_800}
      # 1 inch = 914,400 EMUs
      template_dims = {914_400, 914_400}

      # Act
      result = Image.calculate_scaled_dimensions(source_dims, template_dims)

      # Assert
      assert result == {914_400.0, 914_400.0}
    end
  end

  describe "mime_type_for_extension/1" do
    test "returns mime type for .png" do
      # Arrange
      extension = ".png"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/png"
    end

    test "returns mime type for .jpg" do
      # Arrange
      extension = ".jpg"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/jpeg"
    end

    test "returns mime type for .jpeg" do
      # Arrange
      extension = ".jpeg"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/jpeg"
    end

    test "returns mime type for .gif" do
      # Arrange
      extension = ".gif"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/gif"
    end

    test "returns mime type for extension without dot" do
      # Arrange
      extension = "png"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/png"
    end

    test "handles uppercase extensions" do
      # Arrange
      extension = ".PNG"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == "image/png"
    end

    test "returns nil for unsupported extension" do
      # Arrange
      extension = ".bmp"

      # Act
      result = Image.mime_type_for_extension(extension)

      # Assert
      assert result == nil
    end
  end

  describe "parse_content_types/1" do
    test "parses valid content types XML" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      # Act
      result = Image.parse_content_types(xml)

      # Assert
      assert {:ok, _parsed} = result
    end

    test "returns error for invalid XML" do
      # Arrange
      xml = "not valid xml <>"

      # Act
      result = Image.parse_content_types(xml)

      # Assert
      assert result == {:error, :invalid_xml}
    end

    test "parses empty Types element" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      </Types>
      """

      # Act
      result = Image.parse_content_types(xml)

      # Assert
      assert {:ok, _parsed} = result
    end
  end

  describe "add_content_type/3" do
    test "adds new content type when extension doesn't exist" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      result = Image.add_content_type(types_xml, "png", "image/png")

      # Assert
      xmlElement(content: content) = result

      default_elements =
        Enum.filter(content, fn
          xmlElement(name: :Default) ->
            true

          xmlElement(name: name) ->
            name |> Atom.to_string() |> String.split(":") |> List.last() == "Default"

          _ ->
            false
        end)

      assert length(default_elements) == 2
    end

    test "does not duplicate existing content type" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      result = Image.add_content_type(types_xml, "png", "image/png")

      # Assert
      xmlElement(content: content) = result

      default_elements =
        Enum.filter(content, fn
          xmlElement(name: :Default) ->
            true

          xmlElement(name: name) ->
            name |> Atom.to_string() |> String.split(":") |> List.last() == "Default"

          _ ->
            false
        end)

      assert length(default_elements) == 1
    end

    test "adds multiple different extensions" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      result =
        types_xml
        |> Image.add_content_type("png", "image/png")
        |> Image.add_content_type("jpg", "image/jpeg")
        |> Image.add_content_type("gif", "image/gif")

      # Assert
      xmlElement(content: content) = result

      default_elements =
        Enum.filter(content, fn
          xmlElement(name: :Default) ->
            true

          xmlElement(name: name) ->
            name |> Atom.to_string() |> String.split(":") |> List.last() == "Default"

          _ ->
            false
        end)

      assert length(default_elements) == 3
    end
  end

  describe "serialize_content_types/1" do
    test "serializes content types XML to string" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      {:ok, types_xml} = Image.parse_content_types(xml)

      # Act
      result = Image.serialize_content_types(types_xml)

      # Assert
      assert is_binary(result)
      assert result =~ "Types"
      assert result =~ "Default"
      assert result =~ "Extension"
      assert result =~ "png"
    end

    test "round-trips XML through parse and serialize" do
      # Arrange
      original_xml = """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
      </Types>
      """

      # Act
      {:ok, parsed} = Image.parse_content_types(original_xml)
      serialized = Image.serialize_content_types(parsed)

      # Assert - can parse the serialized version
      assert {:ok, _} = Image.parse_content_types(serialized)
    end
  end

  describe "embed_image/3" do
    test "returns error when image file does not exist" do
      # Arrange
      archive_path = "test/fixtures/templates/simple_template.docx"
      image_path = "/nonexistent/path/image.png"
      media_filename = "image1.png"

      # Act
      result = Image.embed_image(archive_path, image_path, media_filename)

      # Assert
      assert {:error, _} = result
    end

    test "returns error when archive does not exist" do
      # Arrange
      archive_path = "/nonexistent/archive.docx"
      image_path = @test_png_path
      media_filename = "image1.png"

      # Act
      result = Image.embed_image(archive_path, image_path, media_filename)

      # Assert
      assert {:error, _} = result
    end

    test "successfully embeds image into archive" do
      # Arrange
      # Create a copy of the template to test with
      source_path = "test/fixtures/comprehensive_template.docx"
      temp_path = "test/fixtures/temp_embed_test.docx"
      File.cp!(source_path, temp_path)

      image_path = @test_png_path
      media_filename = "image1.png"

      # Act
      result = Image.embed_image(temp_path, image_path, media_filename)

      # Assert
      assert result == :ok

      # Verify the image was added to the archive
      {:ok, files} = :zip.unzip(to_charlist(temp_path), [:memory])
      filenames = Enum.map(files, fn {name, _data} -> to_string(name) end)
      assert "word/media/#{media_filename}" in filenames

      # Cleanup
      File.rm!(temp_path)
    end
  end
end
