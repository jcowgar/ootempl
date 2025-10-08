defmodule Ootempl.Integration.ConditionalFixtureTest do
  @moduledoc """
  Integration tests for conditional section processing using static .docx fixtures.

  These tests use actual .docx files created with Word-compatible formatting
  and stored in test/fixtures/ directory. This ensures:
  - Real-world compatibility with documents created in Word
  - Visual verification of fixtures is possible
  - Tests cover the complete end-to-end workflow with realistic documents
  """

  use ExUnit.Case

  @fixtures_dir "test/fixtures"
  @output_dir "test/fixtures/conditional_fixture_outputs"

  setup_all do
    # Ensure output directory exists
    File.mkdir_p!(@output_dir)
    on_exit(fn -> File.rm_rf!(@output_dir) end)
    :ok
  end

  describe "conditional_simple.docx" do
    test "renders with condition true" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_simple.docx")
      output_path = Path.join(@output_dir, "simple_true.docx")
      data = %{"show_section" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "This content only appears when show_section is true"
      assert output_xml =~ "This content always appears"
      refute output_xml =~ "{{if show_section}}"
      refute output_xml =~ "{{endif}}"
    end

    test "renders with condition false" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_simple.docx")
      output_path = Path.join(@output_dir, "simple_false.docx")
      data = %{"show_section" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      refute output_xml =~ "This content only appears when show_section is true"
      assert output_xml =~ "This content always appears"
      refute output_xml =~ "{{if show_section}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles inspect mode" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_simple.docx")

      # Act
      result = Ootempl.inspect(template_path)

      # Assert
      assert {:ok, info} = result
      assert length(info.conditionals) == 1

      conditional = List.first(info.conditionals)
      assert conditional.condition == "show_section"
      assert conditional.path == ["show_section"]
      assert :document_body in conditional.locations
    end
  end

  describe "conditional_if_else.docx" do
    test "shows if section when condition is true" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_if_else.docx")
      output_path = Path.join(@output_dir, "if_else_true.docx")
      data = %{"is_premium" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "PREMIUM MEMBER: You have access to all features"
      refute output_xml =~ "STANDARD MEMBER: Upgrade to premium"
      refute output_xml =~ "{{if is_premium}}"
      refute output_xml =~ "{{else}}"
      refute output_xml =~ "{{endif}}"
    end

    test "shows else section when condition is false" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_if_else.docx")
      output_path = Path.join(@output_dir, "if_else_false.docx")
      data = %{"is_premium" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      refute output_xml =~ "PREMIUM MEMBER: You have access to all features"
      assert output_xml =~ "STANDARD MEMBER: Upgrade to premium"
      refute output_xml =~ "{{if is_premium}}"
      refute output_xml =~ "{{else}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles inspect mode" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_if_else.docx")

      # Act
      result = Ootempl.inspect(template_path)

      # Assert
      assert {:ok, info} = result
      # Only @if: markers are reported in conditionals, not @else@ or @endif@
      assert length(info.conditionals) == 1

      conditional = List.first(info.conditionals)
      assert conditional.condition == "is_premium"
      assert conditional.path == ["is_premium"]
      assert :document_body in conditional.locations
    end
  end

  describe "conditional_multi_paragraph.docx" do
    test "keeps multi-paragraph section when condition is true" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_multi_paragraph.docx")
      output_path = Path.join(@output_dir, "multi_para_true.docx")
      data = %{"include_warranty" => true}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "WARRANTY SECTION"
      assert output_xml =~ "This product comes with a 2-year warranty"
      assert output_xml =~ "The warranty covers manufacturing defects"
      assert output_xml =~ "For warranty claims, please contact support@example.com"
      refute output_xml =~ "{{if include_warranty}}"
      refute output_xml =~ "{{endif}}"
    end

    test "removes multi-paragraph section when condition is false" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_multi_paragraph.docx")
      output_path = Path.join(@output_dir, "multi_para_false.docx")
      data = %{"include_warranty" => false}

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      refute output_xml =~ "WARRANTY SECTION"
      refute output_xml =~ "This product comes with a 2-year warranty"
      refute output_xml =~ "The warranty covers manufacturing defects"
      assert output_xml =~ "Contract Agreement"
      assert output_xml =~ "End of Contract"
      refute output_xml =~ "{{if include_warranty}}"
      refute output_xml =~ "{{endif}}"
    end
  end

  describe "conditional_nested_path.docx" do
    test "handles nested data paths" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_nested_path.docx")
      output_path = Path.join(@output_dir, "nested_path.docx")

      data = %{
        "customer" => %{
          "active" => true,
          "profile" => %{
            "verified" => true
          }
        }
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "Your account is currently ACTIVE"
      assert output_xml =~ "Profile Status: VERIFIED"
      refute output_xml =~ "{{if customer.active}}"
      refute output_xml =~ "{{if customer.profile.verified}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles missing nested paths" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_nested_path.docx")
      output_path = Path.join(@output_dir, "nested_path_missing.docx")

      data = %{
        "customer" => %{
          "active" => true
          # Missing profile.verified
        }
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert - should fail because customer.profile.verified is not found
      assert {:error, {:file_processing_failed, "word/document.xml", _}} = result
    end

    test "handles inspect mode with nested paths" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_nested_path.docx")

      # Act
      result = Ootempl.inspect(template_path)

      # Assert
      assert {:ok, info} = result
      assert length(info.conditionals) == 2

      # Find the nested path conditionals
      customer_active =
        Enum.find(info.conditionals, fn c ->
          c.condition == "customer.active"
        end)

      customer_verified =
        Enum.find(info.conditionals, fn c ->
          c.condition == "customer.profile.verified"
        end)

      assert customer_active != nil
      assert customer_active.path == ["customer", "active"]
      assert :document_body in customer_active.locations

      assert customer_verified != nil
      assert customer_verified.path == ["customer", "profile", "verified"]
      assert :document_body in customer_verified.locations
    end
  end

  describe "conditional_multiple.docx" do
    test "handles multiple independent conditionals" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_multiple.docx")
      output_path = Path.join(@output_dir, "multiple.docx")

      data = %{
        "show_electronics" => true,
        "show_clothing" => false,
        "show_furniture" => true
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "Electronics Section: Laptops, Phones, Tablets"
      refute output_xml =~ "Clothing Section: Shirts, Pants, Jackets"
      assert output_xml =~ "Furniture Section: Tables, Chairs, Sofas"
      refute output_xml =~ "{{if show_electronics}}"
      refute output_xml =~ "{{if show_clothing}}"
      refute output_xml =~ "{{if show_furniture}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles all conditionals false" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_multiple.docx")
      output_path = Path.join(@output_dir, "multiple_all_false.docx")

      data = %{
        "show_electronics" => false,
        "show_clothing" => false,
        "show_furniture" => false
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      refute output_xml =~ "Electronics Section"
      refute output_xml =~ "Clothing Section"
      refute output_xml =~ "Furniture Section"
      assert output_xml =~ "Product Catalog"
      assert output_xml =~ "End of Catalog"
    end
  end

  describe "conditional_with_variables.docx" do
    test "processes conditionals and variables together" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_with_variables.docx")
      output_path = Path.join(@output_dir, "with_variables.docx")

      data = %{
        "customer_name" => "Alice Johnson",
        "has_discount" => true,
        "discount_percent" => 20,
        "discount_code" => "SAVE20",
        "total_amount" => "$159.99"
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "Dear Alice Johnson"
      assert output_xml =~ "Great news! You have a 20% discount available"
      assert output_xml =~ "Use code: SAVE20"
      assert output_xml =~ "Your order total is: $159.99"
      refute output_xml =~ "{{customer_name}}"
      refute output_xml =~ "{{has_discount}}"
      refute output_xml =~ "{{discount_percent}}"
      refute output_xml =~ "{{discount_code}}"
      refute output_xml =~ "{{total_amount}}"
      refute output_xml =~ "{{if has_discount}}"
      refute output_xml =~ "{{endif}}"
    end

    test "hides discount section when has_discount is false" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_with_variables.docx")
      output_path = Path.join(@output_dir, "without_discount.docx")

      data = %{
        "customer_name" => "Bob Smith",
        "has_discount" => false,
        "discount_percent" => 0,
        "discount_code" => "",
        "total_amount" => "$199.99"
      }

      # Act
      result = Ootempl.render(template_path, data, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
      assert :ok = Ootempl.Validator.validate_docx(output_path)

      # Verify content
      {:ok, output_xml} = extract_document_xml(output_path)
      assert output_xml =~ "Dear Bob Smith"
      refute output_xml =~ "Great news! You have a"
      refute output_xml =~ "Use code:"
      assert output_xml =~ "Your order total is: $199.99"
      refute output_xml =~ "{{customer_name}}"
      refute output_xml =~ "{{if has_discount}}"
      refute output_xml =~ "{{endif}}"
    end

    test "handles inspect mode with variables and conditionals" do
      # Arrange
      template_path = Path.join(@fixtures_dir, "conditional_with_variables.docx")

      # Act
      result = Ootempl.inspect(template_path)

      # Assert
      assert {:ok, info} = result

      # Should find both placeholders and conditionals
      placeholder_paths = Enum.map(info.placeholders, & &1.path)
      assert ["customer_name"] in placeholder_paths
      assert ["discount_percent"] in placeholder_paths
      assert ["discount_code"] in placeholder_paths
      assert ["total_amount"] in placeholder_paths

      # Should find the has_discount conditional
      assert length(info.conditionals) == 1
      conditional = List.first(info.conditionals)
      assert conditional.condition == "has_discount"
      assert conditional.path == ["has_discount"]
    end
  end

  # Helper functions

  defp extract_document_xml(docx_path) do
    OotemplTestHelpers.extract_file_for_test(docx_path, "word/document.xml")
  end
end
