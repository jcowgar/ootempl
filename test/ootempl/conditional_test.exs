defmodule Ootempl.ConditionalTest do
  use ExUnit.Case, async: true
  doctest Ootempl.Conditional

  alias Ootempl.Conditional

  describe "detect_conditionals/1" do
    test "detects @if:variable@ markers" do
      # Arrange
      text = "Hello @if:name@ world"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "name", path: ["name"], position: 6}] = result
    end

    test "detects @endif@ markers" do
      # Arrange
      text = "Hello @endif@ world"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :endif, condition: nil, path: nil, position: 6}] = result
    end

    test "detects both @if@ and @endif@ markers in order" do
      # Arrange
      text = "@if:active@content@endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "active", path: ["active"], position: 0},
               %{type: :endif, condition: nil, path: nil, position: 18}
             ] = result
    end

    test "detects case-insensitive @IF:variable@ markers" do
      # Arrange
      text = "@IF:name@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "name", path: ["name"], position: 0}] = result
    end

    test "detects case-insensitive @If:Variable@ markers" do
      # Arrange
      text = "@If:UserName@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "UserName", path: ["UserName"], position: 0}] = result
    end

    test "detects case-insensitive @ENDIF@ markers" do
      # Arrange
      text = "@if:name@ @ENDIF@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "name", path: ["name"], position: 0},
               %{type: :endif, condition: nil, path: nil, position: 10}
             ] = result
    end

    test "detects nested data paths in conditions" do
      # Arrange
      text = "@if:customer.active@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "customer.active", path: ["customer", "active"], position: 0}
             ] = result
    end

    test "detects deeply nested data paths" do
      # Arrange
      text = "@if:user.profile.name@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{
                 type: :if,
                 condition: "user.profile.name",
                 path: ["user", "profile", "name"],
                 position: 0
               }
             ] = result
    end

    test "returns empty list when no markers present" do
      # Arrange
      text = "No markers in this text"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "handles empty text" do
      # Arrange
      text = ""

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "detects multiple consecutive conditionals" do
      # Arrange
      text = "@if:first@@endif@@if:second@@endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "first", position: 0},
               %{type: :endif, position: 10},
               %{type: :if, condition: "second", position: 17},
               %{type: :endif, position: 28}
             ] = result
    end

    test "handles variables starting with underscore" do
      # Arrange
      text = "@if:_private@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "_private", path: ["_private"], position: 0}] = result
    end

    test "handles variables with numbers" do
      # Arrange
      text = "@if:user123@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "user123", path: ["user123"], position: 0}] = result
    end

    test "ignores malformed @if:@ without variable" do
      # Arrange
      text = "@if:@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "ignores @if@ without variable starting with number" do
      # Arrange
      text = "@if:123name@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "ignores incomplete markers without closing @" do
      # Arrange
      text = "@if:name content @endif"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end
  end

  describe "parse_condition/1" do
    test "parses simple variable name" do
      # Arrange
      condition = "active"

      # Act
      result = Conditional.parse_condition(condition)

      # Assert
      assert ["active"] = result
    end

    test "parses nested data path with dot notation" do
      # Arrange
      condition = "customer.active"

      # Act
      result = Conditional.parse_condition(condition)

      # Assert
      assert ["customer", "active"] = result
    end

    test "parses deeply nested path" do
      # Arrange
      condition = "user.profile.settings.theme"

      # Act
      result = Conditional.parse_condition(condition)

      # Assert
      assert ["user", "profile", "settings", "theme"] = result
    end

    test "handles single segment path" do
      # Arrange
      condition = "name"

      # Act
      result = Conditional.parse_condition(condition)

      # Assert
      assert ["name"] = result
    end
  end

  describe "validate_pairs/1" do
    test "validates properly matched single pair" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "validates properly matched multiple pairs" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "first", path: ["first"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 12},
        %{type: :if, condition: "second", path: ["second"], position: 20},
        %{type: :endif, condition: nil, path: nil, position: 33}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "validates empty list" do
      # Arrange
      conditionals = []

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "returns error for unmatched @if@" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 5}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Unmatched @if:name@ at position 5"} = result
    end

    test "returns error for orphan @endif@" do
      # Arrange
      conditionals = [
        %{type: :endif, condition: nil, path: nil, position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 10 (no matching @if@)"} = result
    end

    test "returns error for @endif@ before @if@" do
      # Arrange
      conditionals = [
        %{type: :endif, condition: nil, path: nil, position: 0},
        %{type: :if, condition: "name", path: ["name"], position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 0 (no matching @if@)"} = result
    end

    test "returns error for multiple unmatched @if@ markers" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "first", path: ["first"], position: 0},
        %{type: :if, condition: "second", path: ["second"], position: 12},
        %{type: :endif, condition: nil, path: nil, position: 25}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Unmatched @if:first@ at position 0"} = result
    end

    test "detects first orphan @endif@ in sequence" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 10},
        %{type: :endif, condition: nil, path: nil, position: 18}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 18 (no matching @if@)"} = result
    end
  end

  describe "integration scenarios" do
    test "handles complex template with multiple sections" do
      # Arrange
      text = """
      Dear @if:customer.premium@Premium@endif@ Customer,

      @if:show_discount@
      Your discount code is: SAVE20
      @endif@

      Thank you!
      """

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert length(conditionals) == 4
      assert :ok = validation
    end

    test "detects validation error in complex template" do
      # Arrange
      text = """
      @if:section1@
      Content 1
      @endif@

      @if:section2@
      Content 2
      """

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, message} = validation
      assert message =~ "Unmatched @if:section2@"
    end

    test "handles template with no conditionals" do
      # Arrange
      text = "Simple template with no conditionals"

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert [] = conditionals
      assert :ok = validation
    end
  end
end
