defmodule Ootempl.PlaceholderTest do
  use ExUnit.Case, async: true

  alias Ootempl.Placeholder

  doctest Placeholder

  describe "detect/1" do
    test "detects single placeholder" do
      # Arrange
      text = "Hello @name@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@name@", variable: "name", path: ["name"]}
             ]
    end

    test "detects multiple placeholders" do
      # Arrange
      text = "@customer.name@ ordered @product.title@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@customer.name@", variable: "customer.name", path: ["customer", "name"]},
               %{
                 original: "@product.title@",
                 variable: "product.title",
                 path: ["product", "title"]
               }
             ]
    end

    test "returns empty list when no placeholders" do
      # Arrange
      text = "No placeholders here"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "detects placeholder at start of text" do
      # Arrange
      text = "@name@ is here"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@name@", variable: "name", path: ["name"]}
             ]
    end

    test "detects placeholder at end of text" do
      # Arrange
      text = "Hello @name@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@name@", variable: "name", path: ["name"]}
             ]
    end

    test "detects nested path placeholder" do
      # Arrange
      text = "Value: @order.items.0.price@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{
                 original: "@order.items.0.price@",
                 variable: "order.items.0.price",
                 path: ["order", "items", "0", "price"]
               }
             ]
    end

    test "supports variable names with underscores" do
      # Arrange
      text = "@first_name@ and @last_name@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@first_name@", variable: "first_name", path: ["first_name"]},
               %{original: "@last_name@", variable: "last_name", path: ["last_name"]}
             ]
    end

    test "supports variable names starting with underscore" do
      # Arrange
      text = "@_private@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@_private@", variable: "_private", path: ["_private"]}
             ]
    end

    test "ignores incomplete placeholders" do
      # Arrange
      text = "@incomplete without closing"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "ignores double at symbols" do
      # Arrange
      text = "@@empty@@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "handles empty text" do
      # Arrange
      text = ""

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "ignores placeholders with leading dots" do
      # Arrange
      text = "@.invalid@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "ignores placeholders starting with numbers" do
      # Arrange
      text = "@123invalid@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "detects deeply nested paths" do
      # Arrange
      text = "@a.b.c.d.e.f@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{
                 original: "@a.b.c.d.e.f@",
                 variable: "a.b.c.d.e.f",
                 path: ["a", "b", "c", "d", "e", "f"]
               }
             ]
    end

    test "handles very long variable names" do
      # Arrange
      long_name = String.duplicate("a", 100)
      text = "@#{long_name}@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@#{long_name}@", variable: long_name, path: [long_name]}
             ]
    end

    test "ignores Unicode characters in variable names" do
      # Arrange
      text = "@naïve@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == []
    end

    test "detects consecutive placeholders" do
      # Arrange
      text = "@first@@second@"

      # Act
      result = Placeholder.detect(text)

      # Assert
      assert result == [
               %{original: "@first@", variable: "first", path: ["first"]},
               %{original: "@second@", variable: "second", path: ["second"]}
             ]
    end
  end

  describe "parse_path/1" do
    test "parses single-level path" do
      # Arrange
      variable = "name"

      # Act
      result = Placeholder.parse_path(variable)

      # Assert
      assert result == ["name"]
    end

    test "parses nested path" do
      # Arrange
      variable = "customer.name"

      # Act
      result = Placeholder.parse_path(variable)

      # Assert
      assert result == ["customer", "name"]
    end

    test "parses path with array index" do
      # Arrange
      variable = "order.items.0.price"

      # Act
      result = Placeholder.parse_path(variable)

      # Assert
      assert result == ["order", "items", "0", "price"]
    end

    test "parses deeply nested path" do
      # Arrange
      variable = "a.b.c.d.e.f"

      # Act
      result = Placeholder.parse_path(variable)

      # Assert
      assert result == ["a", "b", "c", "d", "e", "f"]
    end

    test "handles empty string" do
      # Arrange
      variable = ""

      # Act
      result = Placeholder.parse_path(variable)

      # Assert
      assert result == [""]
    end
  end

  describe "valid?/1" do
    test "returns true for valid simple placeholder" do
      # Arrange
      text = "@name@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == true
    end

    test "returns true for valid nested placeholder" do
      # Arrange
      text = "@customer.name@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == true
    end

    test "returns false for incomplete placeholder" do
      # Arrange
      text = "@incomplete"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns false for text without at symbols" do
      # Arrange
      text = "not a placeholder"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns false for double at symbols" do
      # Arrange
      text = "@@empty@@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns true for placeholder with underscores" do
      # Arrange
      text = "@first_name@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == true
    end

    test "returns false for placeholder starting with number" do
      # Arrange
      text = "@123invalid@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns false for placeholder with leading dot" do
      # Arrange
      text = "@.invalid@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns false for placeholder with trailing dot" do
      # Arrange
      text = "@invalid.@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns true for deeply nested placeholder" do
      # Arrange
      text = "@a.b.c.d.e@"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == true
    end

    test "returns false for text with placeholder in middle" do
      # Arrange
      text = "Hello @name@ there"

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end

    test "returns false for empty string" do
      # Arrange
      text = ""

      # Act
      result = Placeholder.valid?(text)

      # Assert
      assert result == false
    end
  end
end
