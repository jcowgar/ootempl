defmodule Ootempl.ErrorsTest do
  use ExUnit.Case, async: true

  alias Ootempl.InvalidArchiveError
  alias Ootempl.MalformedXMLError
  alias Ootempl.MissingFileError
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
end
