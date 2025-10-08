defmodule Ootempl.ErrorsTest do
  use ExUnit.Case, async: true

  alias Ootempl.ImageError
  alias Ootempl.InvalidArchiveError
  alias Ootempl.MalformedXMLError
  alias Ootempl.MissingFileError
  alias Ootempl.PlaceholderError
  alias Ootempl.ValidationError

  describe "InvalidArchiveError" do
    # Arrange, Act, Assert

    test "creates exception with clear message" do
      # Arrange
      path = "/path/to/file.docx"
      reason = :enoent

      # Act
      exception = InvalidArchiveError.exception(path: path, reason: reason)

      # Assert
      assert %InvalidArchiveError{} = exception
      assert exception.path == path
      assert exception.reason == reason
      assert exception.message =~ "Invalid ZIP archive"
      assert exception.message =~ path
      assert exception.message =~ inspect(reason)
    end

    test "can be raised" do
      # Arrange
      path = "/path/to/file.docx"
      reason = :bad_zip

      # Act & Assert
      assert_raise InvalidArchiveError, fn ->
        raise InvalidArchiveError, path: path, reason: reason
      end
    end
  end

  describe "MissingFileError" do
    # Arrange, Act, Assert

    test "creates exception with clear message" do
      # Arrange
      path = "/path/to/file.docx"
      missing_file = "word/document.xml"

      # Act
      exception = MissingFileError.exception(path: path, missing_file: missing_file)

      # Assert
      assert %MissingFileError{} = exception
      assert exception.path == path
      assert exception.missing_file == missing_file
      assert exception.message =~ "Required file missing"
      assert exception.message =~ path
      assert exception.message =~ missing_file
    end

    test "can be raised" do
      # Arrange
      path = "/path/to/file.docx"
      missing_file = "[Content_Types].xml"

      # Act & Assert
      assert_raise MissingFileError, fn ->
        raise MissingFileError, path: path, missing_file: missing_file
      end
    end
  end

  describe "MalformedXMLError" do
    # Arrange, Act, Assert

    test "creates exception with clear message" do
      # Arrange
      path = "/path/to/file.docx"
      xml_file = "word/document.xml"
      reason = {:fatal, {:expected_element_start_tag}}

      # Act
      exception = MalformedXMLError.exception(path: path, xml_file: xml_file, reason: reason)

      # Assert
      assert %MalformedXMLError{} = exception
      assert exception.path == path
      assert exception.xml_file == xml_file
      assert exception.reason == reason
      assert exception.message =~ "Malformed XML"
      assert exception.message =~ path
      assert exception.message =~ xml_file
    end

    test "handles unknown reason" do
      # Arrange
      path = "/path/to/file.docx"
      xml_file = "word/document.xml"

      # Act
      exception = MalformedXMLError.exception(path: path, xml_file: xml_file)

      # Assert
      assert %MalformedXMLError{} = exception
      assert exception.reason == :unknown
      assert exception.message =~ "Malformed XML"
    end

    test "can be raised" do
      # Arrange
      path = "/path/to/file.docx"
      xml_file = "word/document.xml"
      reason = {:fatal, :unexpected_end}

      # Act & Assert
      assert_raise MalformedXMLError, fn ->
        raise MalformedXMLError, path: path, xml_file: xml_file, reason: reason
      end
    end
  end

  describe "ValidationError" do
    # Arrange, Act, Assert

    test "creates exception for file_not_found" do
      # Arrange
      path = "/path/to/nonexistent.docx"
      reason = :file_not_found

      # Act
      exception = ValidationError.exception(path: path, reason: reason)

      # Assert
      assert %ValidationError{} = exception
      assert exception.path == path
      assert exception.reason == reason
      assert exception.message =~ "File not found"
      assert exception.message =~ path
    end

    test "creates exception for not_a_file" do
      # Arrange
      path = "/path/to/directory"
      reason = :not_a_file

      # Act
      exception = ValidationError.exception(path: path, reason: reason)

      # Assert
      assert %ValidationError{} = exception
      assert exception.path == path
      assert exception.reason == reason
      assert exception.message =~ "Not a regular file"
      assert exception.message =~ path
    end

    test "creates exception for generic reason" do
      # Arrange
      path = "/path/to/file.docx"
      reason = :custom_validation_failure

      # Act
      exception = ValidationError.exception(path: path, reason: reason)

      # Assert
      assert %ValidationError{} = exception
      assert exception.path == path
      assert exception.reason == reason
      assert exception.message =~ "Validation failed"
      assert exception.message =~ path
      assert exception.message =~ inspect(reason)
    end

    test "can be raised" do
      # Arrange
      path = "/path/to/file.docx"
      reason = :file_not_found

      # Act & Assert
      assert_raise ValidationError, fn ->
        raise ValidationError, path: path, reason: reason
      end
    end
  end

  describe "PlaceholderError" do
    test "creates exception with single placeholder" do
      # Arrange
      placeholders = [
        %{placeholder: "{{name}}", reason: {:path_not_found, ["name"]}}
      ]

      # Act
      exception = PlaceholderError.exception(placeholders: placeholders)

      # Assert
      assert %PlaceholderError{} = exception
      assert exception.placeholders == placeholders
      assert exception.message =~ "Placeholder {{name}} could not be resolved"
    end

    test "creates exception with multiple placeholders" do
      # Arrange
      placeholders = [
        %{placeholder: "{{name}}", reason: {:path_not_found, ["name"]}},
        %{placeholder: "{{email}}", reason: {:path_not_found, ["email"]}},
        %{placeholder: "{{age}}", reason: :nil_value}
      ]

      # Act
      exception = PlaceholderError.exception(placeholders: placeholders)

      # Assert
      assert %PlaceholderError{} = exception
      assert exception.placeholders == placeholders
      assert exception.message =~ "3 placeholders could not be resolved"
      assert exception.message =~ "{{name}}"
    end

    test "creates exception with empty placeholder list" do
      # Arrange
      placeholders = []

      # Act
      exception = PlaceholderError.exception(placeholders: placeholders)

      # Assert
      assert %PlaceholderError{} = exception
      assert exception.placeholders == []
      assert exception.message =~ "No placeholders could be resolved"
    end

    test "preserves all error reasons" do
      # Arrange
      placeholders = [
        %{placeholder: "{{missing}}", reason: {:path_not_found, ["missing"]}},
        %{placeholder: "{{ambiguous}}", reason: {:ambiguous_key, "name", ["Name", "name"]}},
        %{placeholder: "{{nil}}", reason: :nil_value},
        %{placeholder: "{{bad_index}}", reason: {:invalid_index, "abc"}},
        %{placeholder: "{{oob}}", reason: {:index_out_of_bounds, 5, 3}}
      ]

      # Act
      exception = PlaceholderError.exception(placeholders: placeholders)

      # Assert
      assert %PlaceholderError{} = exception
      assert length(exception.placeholders) == 5
      assert exception.message =~ "5 placeholders"
    end

    test "can be raised" do
      # Arrange
      placeholders = [%{placeholder: "{{test}}", reason: :nil_value}]

      # Act & Assert
      assert_raise PlaceholderError, fn ->
        raise PlaceholderError, placeholders: placeholders
      end
    end
  end

  describe "ImageError" do
    test "creates exception for image_not_found_in_data" do
      # Arrange
      placeholder_name = "logo"
      reason = :image_not_found_in_data

      # Act
      exception = ImageError.exception(placeholder_name: placeholder_name, reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.placeholder_name == placeholder_name
      assert exception.image_path == nil
      assert exception.reason == reason
      assert exception.message =~ "logo"
      assert exception.message =~ "no corresponding data key"
    end

    test "creates exception for file_not_found" do
      # Arrange
      placeholder_name = "logo"
      image_path = "/missing/logo.png"
      reason = :file_not_found

      # Act
      exception =
        ImageError.exception(placeholder_name: placeholder_name, image_path: image_path, reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.placeholder_name == placeholder_name
      assert exception.image_path == image_path
      assert exception.reason == reason
      assert exception.message =~ "not found"
      assert exception.message =~ image_path
    end

    test "creates exception for file_not_readable" do
      # Arrange
      placeholder_name = "logo"
      image_path = "/restricted/logo.png"
      reason = :file_not_readable

      # Act
      exception =
        ImageError.exception(placeholder_name: placeholder_name, image_path: image_path, reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.reason == reason
      assert exception.message =~ "cannot be read"
    end

    test "creates exception for unsupported_format" do
      # Arrange
      placeholder_name = "logo"
      image_path = "logo.bmp"
      reason = :unsupported_format

      # Act
      exception =
        ImageError.exception(placeholder_name: placeholder_name, image_path: image_path, reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.reason == reason
      assert exception.message =~ "Unsupported"
      assert exception.message =~ "PNG, JPEG, GIF"
    end

    test "creates exception for cannot_read_dimensions" do
      # Arrange
      placeholder_name = "logo"
      image_path = "corrupt.png"
      reason = :cannot_read_dimensions

      # Act
      exception =
        ImageError.exception(placeholder_name: placeholder_name, image_path: image_path, reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.reason == reason
      assert exception.message =~ "dimensions"
    end

    test "handles missing placeholder_name gracefully" do
      # Arrange
      reason = :file_not_found

      # Act
      exception = ImageError.exception(reason: reason)

      # Assert
      assert %ImageError{} = exception
      assert exception.placeholder_name == nil
      assert is_binary(exception.message)
    end

    test "can be raised" do
      # Arrange
      placeholder_name = "logo"
      reason = :file_not_found

      # Act & Assert
      assert_raise ImageError, fn ->
        raise ImageError, placeholder_name: placeholder_name, reason: reason
      end
    end
  end
end
