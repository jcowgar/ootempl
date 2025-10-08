defmodule Ootempl.Integration.ConditionalRenderTest do
  @moduledoc """
  Integration tests for conditional section processing through Ootempl.render/3.

  These tests verify the complete end-to-end workflow:
  - Creating .docx templates with conditional markers
  - Processing through the full render pipeline
  - Validating generated .docx files are valid
  - Verifying conditional content is shown/hidden correctly
  """

  use ExUnit.Case

  import Ootempl.FixtureHelper

  @output_dir "test/fixtures/conditional_outputs"

  setup_all do
    # Ensure output directory exists
    File.mkdir_p!(@output_dir)
    on_exit(fn -> File.rm_rf!(@output_dir) end)
    :ok
  end

  describe "simple conditional section" do
    test "removes section when condition is false" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_template.docx")
      output_path = Path.join(@output_dir, "simple_false_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{"show_section" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify conditional section was removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Before conditional"
      assert output_xml =~ "After conditional"
      refute output_xml =~ "Conditional content that should appear or disappear"
      refute output_xml =~ "{{if show_section}}"
      refute output_xml =~ "{{endif}}"
    end

    test "keeps section and removes markers when condition is true" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_true_template.docx")
      output_path = Path.join(@output_dir, "simple_true_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{"show_section" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify section was kept, markers removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Before conditional"
      assert output_xml =~ "Conditional content that should appear or disappear"
      assert output_xml =~ "After conditional"
      refute output_xml =~ "{{if show_section}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles truthiness correctly with zero" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_zero_template.docx")
      output_path = Path.join(@output_dir, "simple_zero_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{"show_section" => 0}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify section was removed (0 is falsy)
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      refute output_xml =~ "Conditional content that should appear or disappear"
    end

    test "handles truthiness correctly with empty string" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_empty_template.docx")
      output_path = Path.join(@output_dir, "simple_empty_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{"show_section" => ""}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify section was removed (empty string is falsy)
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      refute output_xml =~ "Conditional content that should appear or disappear"
    end

    test "handles truthiness correctly with non-zero number" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_nonzero_template.docx")
      output_path = Path.join(@output_dir, "simple_nonzero_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{"show_section" => 1}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify section was kept (non-zero is truthy)
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Conditional content that should appear or disappear"
    end

    test "returns error when condition variable not found" do
      # Arrange
      template_path = Path.join(@output_dir, "simple_missing_template.docx")
      output_path = Path.join(@output_dir, "simple_missing_output.docx")
      create_conditional_simple_docx(template_path)

      data = %{}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert {:error, {:file_processing_failed, "word/document.xml", _error_detail}} = result
    end
  end

  describe "multi-paragraph conditional section" do
    test "removes all paragraphs in section when condition is false" do
      # Arrange
      template_path = Path.join(@output_dir, "multi_false_template.docx")
      output_path = Path.join(@output_dir, "multi_false_output.docx")
      create_conditional_multi_paragraph_docx(template_path)

      data = %{"show_disclaimer" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify all disclaimer paragraphs were removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Document start"
      assert output_xml =~ "Document end"
      refute output_xml =~ "DISCLAIMER PARAGRAPH 1"
      refute output_xml =~ "DISCLAIMER PARAGRAPH 2"
      refute output_xml =~ "DISCLAIMER PARAGRAPH 3"
      refute output_xml =~ "{{if show_disclaimer}}"
      refute output_xml =~ "{{endif}}"
    end

    test "keeps all paragraphs in section when condition is true" do
      # Arrange
      template_path = Path.join(@output_dir, "multi_true_template.docx")
      output_path = Path.join(@output_dir, "multi_true_output.docx")
      create_conditional_multi_paragraph_docx(template_path)

      data = %{"show_disclaimer" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify all disclaimer paragraphs were kept
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Document start"
      assert output_xml =~ "DISCLAIMER PARAGRAPH 1"
      assert output_xml =~ "DISCLAIMER PARAGRAPH 2"
      assert output_xml =~ "DISCLAIMER PARAGRAPH 3"
      assert output_xml =~ "Document end"
      refute output_xml =~ "{{if show_disclaimer}}"
      refute output_xml =~ "{{endif}}"
    end
  end

  describe "multiple consecutive conditionals" do
    test "handles multiple conditionals with mixed true/false values" do
      # Arrange
      template_path = Path.join(@output_dir, "multiple_template.docx")
      output_path = Path.join(@output_dir, "multiple_output.docx")
      create_conditional_multiple_docx(template_path)

      data = %{"first" => true, "second" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify first conditional kept, second removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Start"
      assert output_xml =~ "First conditional content"
      assert output_xml =~ "Middle"
      refute output_xml =~ "Second conditional content"
      assert output_xml =~ "End"
      refute output_xml =~ "@if:"
      refute output_xml =~ "{{endif}}"
    end

    test "handles all conditionals true" do
      # Arrange
      template_path = Path.join(@output_dir, "multiple_all_true_template.docx")
      output_path = Path.join(@output_dir, "multiple_all_true_output.docx")
      create_conditional_multiple_docx(template_path)

      data = %{"first" => true, "second" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify all conditionals kept
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "First conditional content"
      assert output_xml =~ "Second conditional content"
    end

    test "handles all conditionals false" do
      # Arrange
      template_path = Path.join(@output_dir, "multiple_all_false_template.docx")
      output_path = Path.join(@output_dir, "multiple_all_false_output.docx")
      create_conditional_multiple_docx(template_path)

      data = %{"first" => false, "second" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify all conditionals removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      refute output_xml =~ "First conditional content"
      refute output_xml =~ "Second conditional content"
      assert output_xml =~ "Start"
      assert output_xml =~ "Middle"
      assert output_xml =~ "End"
    end
  end

  describe "conditional section with table" do
    test "removes table when condition is false" do
      # Arrange
      template_path = Path.join(@output_dir, "table_false_template.docx")
      output_path = Path.join(@output_dir, "table_false_output.docx")
      create_conditional_with_table_docx(template_path)

      data = %{"show_pricing" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify table was removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Before table"
      assert output_xml =~ "After table"
      refute output_xml =~ "Product A"
      refute output_xml =~ "$100"
      refute output_xml =~ "<w:tbl"
      refute output_xml =~ "{{if show_pricing}}"
      refute output_xml =~ "{{endif}}"
    end

    test "keeps table when condition is true" do
      # Arrange
      template_path = Path.join(@output_dir, "table_true_template.docx")
      output_path = Path.join(@output_dir, "table_true_output.docx")
      create_conditional_with_table_docx(template_path)

      data = %{"show_pricing" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify table was kept
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Before table"
      assert output_xml =~ "Product A"
      assert output_xml =~ "$100"
      assert output_xml =~ "<w:tbl"
      assert output_xml =~ "After table"
      refute output_xml =~ "{{if show_pricing}}"
      refute output_xml =~ "{{endif}}"
    end
  end

  describe "conditional with variables" do
    test "processes conditionals before variable replacement" do
      # Arrange
      template_path = Path.join(@output_dir, "cond_var_template.docx")
      output_path = Path.join(@output_dir, "cond_var_output.docx")

      # Create template with both conditional and variable
      file_map = %{
        "[Content_Types].xml" => content_types_xml(),
        "_rels/.rels" => rels_xml(),
        "word/document.xml" => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Hello {{name}}</w:t></w:r></w:p>
            <w:p><w:r><w:t>{{if show_message}}</w:t></w:r></w:p>
            <w:p><w:r><w:t>Message: {{message}}</w:t></w:r></w:p>
            <w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """,
        "word/_rels/document.xml.rels" => document_rels_xml()
      }

      Ootempl.Archive.create(file_map, template_path)

      data = %{"name" => "Alice", "show_message" => false, "message" => "Secret"}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify variable was replaced but conditional section was removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Hello Alice"
      refute output_xml =~ "Message: Secret"
      refute output_xml =~ "{{message}}"
      refute output_xml =~ "{{if show_message}}"
    end
  end

  describe "if/else conditional sections" do
    test "shows if section when condition is true" do
      # Arrange
      template_path = Path.join(@output_dir, "if_else_true_template.docx")
      output_path = Path.join(@output_dir, "if_else_true_output.docx")
      create_conditional_if_else_docx(template_path)

      data = %{"is_premium" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify if section was kept, else section and markers removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Dear Customer,"
      assert output_xml =~ "Thank you for being a premium member! You get 20% off."
      refute output_xml =~ "Become a premium member today for 20% off all purchases."
      assert output_xml =~ "Thank you!"
      refute output_xml =~ "{{if is_premium}}"
      refute output_xml =~ "{{else}}"
      refute output_xml =~ "{{endif}}"
    end

    test "shows else section when condition is false" do
      # Arrange
      template_path = Path.join(@output_dir, "if_else_false_template.docx")
      output_path = Path.join(@output_dir, "if_else_false_output.docx")
      create_conditional_if_else_docx(template_path)

      data = %{"is_premium" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify output is valid .docx
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify else section was kept, if section and markers removed
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Dear Customer,"
      refute output_xml =~ "Thank you for being a premium member! You get 20% off."
      assert output_xml =~ "Become a premium member today for 20% off all purchases."
      assert output_xml =~ "Thank you!"
      refute output_xml =~ "{{if is_premium}}"
      refute output_xml =~ "{{else}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles falsy values correctly in if/else" do
      # Arrange
      template_path = Path.join(@output_dir, "if_else_zero_template.docx")
      output_path = Path.join(@output_dir, "if_else_zero_output.docx")
      create_conditional_if_else_docx(template_path)

      data = %{"is_premium" => 0}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok

      # Verify else section was kept (0 is falsy)
      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(output_path, "word/document.xml")
      assert output_xml =~ "Become a premium member today for 20% off all purchases."
      refute output_xml =~ "Thank you for being a premium member! You get 20% off."
    end
  end

  # Note: Case-insensitive marker text matching is a known limitation.
  # Markers are detected case-insensitively, but the exact case must match when searching paragraphs.
  # This is tracked as technical debt for future improvement.

  # Helper functions from FixtureHelper for inline template creation
  defp content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """
  end

  defp rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """
  end

  defp document_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """
  end
end
