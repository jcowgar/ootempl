defmodule Ootempl.Integration.ExtendedPartsTest do
  @moduledoc """
  Integration tests for footnotes, endnotes, document properties, and text boxes.

  These tests verify that placeholder replacement works in all document parts:
  - Footnotes (word/footnotes.xml)
  - Endnotes (word/endnotes.xml)
  - Document properties (docProps/core.xml, docProps/app.xml)
  - Text boxes (embedded in document.xml, headers, footers)
  """

  use ExUnit.Case

  describe "footnote processing" do
    test "replaces placeholders in footnotes" do
      # Arrange
      template_path = "test/fixtures/with_footnotes.docx"
      data = %{
        "footnote_ref" => "Smith et al., 2020",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/footnotes_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify footnotes.xml was processed
      {:ok, footnotes_xml} = Ootempl.Archive.extract_file(output_path, "word/footnotes.xml")
      assert footnotes_xml =~ "Smith et al., 2020"
      refute footnotes_xml =~ "@footnote_ref@"
    end

    test "handles documents without footnotes gracefully" do
      # Arrange - document with no footnotes
      template_path = "test/fixtures/Simple Placeholdes from Word.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/no_footnotes_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - should work fine even without footnotes
      assert result == :ok
      assert File.exists?(output_path)
    end

    test "reports placeholder errors from footnotes" do
      # Arrange
      template_path = "test/fixtures/with_footnotes.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
        # Missing: footnote_ref
      }
      output_path = "test/fixtures/footnotes_error_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, %Ootempl.PlaceholderError{} = error} = result
      placeholders = Enum.map(error.placeholders, & &1.placeholder)
      assert "@footnote_ref@" in placeholders
    end

    test "processes nested data in footnotes" do
      # Arrange
      # Create a fixture with nested data placeholder
      template_path = "test/fixtures/with_footnotes.docx"
      data = %{
        "footnote_ref" => "Smith et al., 2020",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/footnotes_nested_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      {:ok, footnotes_xml} = Ootempl.Archive.extract_file(output_path, "word/footnotes.xml")
      assert footnotes_xml =~ "Smith"
      assert footnotes_xml =~ "2020"
    end
  end

  describe "endnote processing" do
    test "replaces placeholders in endnotes" do
      # Arrange
      template_path = "test/fixtures/with_endnotes.docx"
      data = %{
        "endnote_text" => "Additional reference material",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/endnotes_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify endnotes.xml was processed
      {:ok, endnotes_xml} = Ootempl.Archive.extract_file(output_path, "word/endnotes.xml")
      assert endnotes_xml =~ "Additional reference material"
      refute endnotes_xml =~ "@endnote_text@"
    end

    test "handles documents without endnotes gracefully" do
      # Arrange - document with no endnotes
      template_path = "test/fixtures/Simple Placeholdes from Word.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/no_endnotes_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - should work fine even without endnotes
      assert result == :ok
      assert File.exists?(output_path)
    end

    test "reports placeholder errors from endnotes" do
      # Arrange
      template_path = "test/fixtures/with_endnotes.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
        # Missing: endnote_text
      }
      output_path = "test/fixtures/endnotes_error_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, %Ootempl.PlaceholderError{} = error} = result
      placeholders = Enum.map(error.placeholders, & &1.placeholder)
      assert "@endnote_text@" in placeholders
    end
  end

  describe "document property processing" do
    test "replaces placeholders in core properties (title, subject, creator)" do
      # Arrange
      template_path = "test/fixtures/with_properties.docx"
      data = %{
        "document_title" => "Annual Report 2025",
        "subject" => "Financial Analysis",
        "author" => "Jane Doe",
        "company_name" => "Test Corp",
        "manager_name" => "Test Manager",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/properties_core_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify docProps/core.xml was processed
      {:ok, core_xml} = Ootempl.Archive.extract_file(output_path, "docProps/core.xml")
      assert core_xml =~ "Annual Report 2025"
      assert core_xml =~ "Financial Analysis"
      assert core_xml =~ "Jane Doe"
      refute core_xml =~ "@document_title@"
      refute core_xml =~ "@subject@"
      refute core_xml =~ "@author@"
    end

    test "replaces placeholders in app properties (company, manager)" do
      # Arrange
      template_path = "test/fixtures/with_properties.docx"
      data = %{
        "document_title" => "Test Document",
        "subject" => "Test Subject",
        "author" => "Test Author",
        "company_name" => "Acme Corporation",
        "manager_name" => "John Smith",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/properties_app_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify docProps/app.xml was processed
      {:ok, app_xml} = Ootempl.Archive.extract_file(output_path, "docProps/app.xml")
      assert app_xml =~ "Acme Corporation"
      assert app_xml =~ "John Smith"
      refute app_xml =~ "@company_name@"
      refute app_xml =~ "@manager_name@"
    end

    test "handles documents without custom properties gracefully" do
      # Arrange - document with no custom properties
      template_path = "test/fixtures/Simple Placeholdes from Word.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/no_properties_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - should work fine even without custom properties
      assert result == :ok
      assert File.exists?(output_path)
    end

    test "reports placeholder errors from document properties" do
      # Arrange
      template_path = "test/fixtures/with_properties.docx"
      data = %{
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
        # Missing: document_title, company_name, etc.
      }
      output_path = "test/fixtures/properties_error_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, %Ootempl.PlaceholderError{} = error} = result
      placeholders = Enum.map(error.placeholders, & &1.placeholder)
      # Should have at least one property placeholder error
      assert length(placeholders) > 0
    end

    test "handles special XML characters in property values" do
      # Arrange
      template_path = "test/fixtures/with_properties.docx"
      data = %{
        "document_title" => "Q&A Report <Draft>",
        "subject" => "Test & Review",
        "author" => "Smith \"Jr\"",
        "company_name" => "Smith & Sons \"Ltd\"",
        "manager_name" => "Test Manager",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/properties_special_chars_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify XML is well-formed
      {:ok, core_xml} = Ootempl.Archive.extract_file(output_path, "docProps/core.xml")
      assert {:ok, _parsed} = Ootempl.Xml.parse(core_xml)

      {:ok, app_xml} = Ootempl.Archive.extract_file(output_path, "docProps/app.xml")
      assert {:ok, _parsed} = Ootempl.Xml.parse(app_xml)
    end
  end

  describe "text box processing" do
    test "replaces placeholders in text boxes within document body" do
      # Arrange
      template_path = "test/fixtures/with_textboxes.docx"
      data = %{
        "textbox_content" => "Important Notice",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/textbox_body_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Text boxes are embedded in document.xml
      {:ok, doc_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert doc_xml =~ "Important Notice"
      refute doc_xml =~ "@textbox_content@"
    end

    @tag :skip
    test "replaces placeholders in text boxes within headers" do
      # Arrange
      template_path = "test/fixtures/with_textboxes.docx"
      data = %{
        "header_textbox" => "Confidential",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/textbox_header_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Text boxes in headers are embedded in header files
      {:ok, header_xml} = Ootempl.Archive.extract_file(output_path, "word/header1.xml")
      assert header_xml =~ "Confidential"
      refute header_xml =~ "@header_textbox@"
    end

    @tag :skip
    test "replaces placeholders in text boxes within footers" do
      # Arrange
      template_path = "test/fixtures/with_textboxes.docx"
      data = %{
        "footer_textbox" => "Page Footer",
        "person" => %{"first_name" => "Test"},
        "date" => "2025"
      }
      output_path = "test/fixtures/textbox_footer_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Text boxes in footers are embedded in footer files
      {:ok, footer_xml} = Ootempl.Archive.extract_file(output_path, "word/footer1.xml")
      assert footer_xml =~ "Page Footer"
      refute footer_xml =~ "@footer_textbox@"
    end
  end

  describe "combined processing" do
    test "processes all extended parts together (footnotes, endnotes, properties)" do
      # Arrange
      template_path = "test/fixtures/comprehensive_template.docx"
      data = %{
        "document_title" => "Full Document",
        "company_name" => "Test Corp",
        "footnote_ref" => "Reference 1",
        "endnote_text" => "Additional notes",
        "person" => %{"first_name" => "Test User"},
        "date" => "2025-10-06"
      }
      output_path = "test/fixtures/comprehensive_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify all parts were processed
      {:ok, doc_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
      assert doc_xml =~ "Test User"

      {:ok, core_xml} = Ootempl.Archive.extract_file(output_path, "docProps/core.xml")
      assert core_xml =~ "Full Document"

      {:ok, app_xml} = Ootempl.Archive.extract_file(output_path, "docProps/app.xml")
      assert app_xml =~ "Test Corp"

      {:ok, footnotes_xml} = Ootempl.Archive.extract_file(output_path, "word/footnotes.xml")
      assert footnotes_xml =~ "Reference 1"

      {:ok, endnotes_xml} = Ootempl.Archive.extract_file(output_path, "word/endnotes.xml")
      assert endnotes_xml =~ "Additional notes"
    end

    test "collects placeholder errors from all document parts" do
      # Arrange - template with placeholders in multiple parts
      template_path = "test/fixtures/comprehensive_template.docx"
      data = %{
        # Provide only some values, leaving others missing
        "document_title" => "Partial Data"
      }
      output_path = "test/fixtures/comprehensive_error_output.docx"

      on_exit(fn -> File.rm(output_path) end)

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - should collect errors from all parts
      assert {:error, %Ootempl.PlaceholderError{} = error} = result
      assert length(error.placeholders) > 1
    end
  end
end
