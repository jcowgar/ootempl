defmodule Ootempl.DataAccessTest do
  use ExUnit.Case, async: true

  alias Ootempl.DataAccess

  doctest DataAccess

  describe "get_value/2 - flat map access" do
    test "retrieves simple string value" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "retrieves number and converts to string" do
      # Arrange
      data = %{"age" => 30}

      # Act
      result = DataAccess.get_value(data, ["age"])

      # Assert
      assert result == {:ok, "30"}
    end

    test "retrieves boolean true and converts to string" do
      # Arrange
      data = %{"active" => true}

      # Act
      result = DataAccess.get_value(data, ["active"])

      # Assert
      assert result == {:ok, "true"}
    end

    test "retrieves boolean false and converts to string" do
      # Arrange
      data = %{"disabled" => false}

      # Act
      result = DataAccess.get_value(data, ["disabled"])

      # Assert
      assert result == {:ok, "false"}
    end

    test "retrieves float and converts to string" do
      # Arrange
      data = %{"price" => 99.99}

      # Act
      result = DataAccess.get_value(data, ["price"])

      # Assert
      assert result == {:ok, "99.99"}
    end

    test "returns error when key not found" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, ["missing"])

      # Assert
      assert result == {:error, {:path_not_found, ["missing"]}}
    end

    test "returns error for nil value" do
      # Arrange
      data = %{"value" => nil}

      # Act
      result = DataAccess.get_value(data, ["value"])

      # Assert
      assert result == {:error, :nil_value}
    end
  end

  describe "get_value/2 - case-insensitive matching" do
    test "matches lowercase key with lowercase lookup" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "matches lowercase key with uppercase lookup" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, ["NAME"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "matches lowercase key with mixed case lookup" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, ["Name"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "matches uppercase key with lowercase lookup" do
      # Arrange
      data = %{"NAME" => "John"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "matches mixed case key with different case lookup" do
      # Arrange
      data = %{"FirstName" => "John"}

      # Act
      result = DataAccess.get_value(data, ["firstname"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "returns error when multiple case variants exist" do
      # Arrange
      data = %{"name" => "John", "Name" => "Jane"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:error, {:ambiguous_key, "name", ["Name", "name"]}}
    end

    test "returns error when three case variants exist" do
      # Arrange
      data = %{"name" => "John", "Name" => "Jane", "NAME" => "Jack"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      {:error, {:ambiguous_key, "name", matches}} = result
      assert length(matches) == 3
      assert "name" in matches
      assert "Name" in matches
      assert "NAME" in matches
    end
  end

  describe "get_value/2 - atom key support" do
    test "retrieves value from map with atom keys" do
      # Arrange
      data = %{name: "John", age: 30}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "matches atom keys case-insensitively" do
      # Arrange
      data = %{FirstName: "John"}

      # Act
      result = DataAccess.get_value(data, ["firstname"])

      # Assert
      assert result == {:ok, "John"}
    end

    test "traverses nested maps with atom keys" do
      # Arrange
      data = %{
        customer: %{
          name: "Jane",
          email: "jane@example.com"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer", "name"])

      # Assert
      assert result == {:ok, "Jane"}
    end

    test "handles mixed atom and string keys in different levels" do
      # Arrange
      data = %{
        customer: %{
          "name" => "Jane",
          "email" => "jane@example.com"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer", "name"])

      # Assert
      assert result == {:ok, "Jane"}
    end

    test "returns error when both atom and string versions of key exist" do
      # Arrange
      data = %{:name => "Atom John", "name" => "String John"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:error, {:conflicting_key_types, "name", :name, "name"}}
    end

    test "returns error when both atom and string versions exist (case variants)" do
      # Arrange
      data = %{:Name => "Atom John", "name" => "String John"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      assert result == {:error, {:conflicting_key_types, "name", :Name, "name"}}
    end

    test "handles multiple atom case variants as ambiguous" do
      # Arrange
      data = %{:name => "lowercase", :Name => "capitalized", :NAME => "uppercase"}

      # Act
      result = DataAccess.get_value(data, ["name"])

      # Assert
      {:error, {:ambiguous_key, "name", matches}} = result
      assert length(matches) == 3
      assert :NAME in matches
      assert :Name in matches
      assert :name in matches
    end

    test "works with complex nested structure mixing atom and string keys" do
      # Arrange
      data = %{
        order: %{
          "items" => [
            %{price: 99.99},
            %{"price" => 49.99}
          ]
        }
      }

      # Act
      result1 = DataAccess.get_value(data, ["order", "items", "0", "price"])
      result2 = DataAccess.get_value(data, ["order", "items", "1", "price"])

      # Assert
      assert result1 == {:ok, "99.99"}
      assert result2 == {:ok, "49.99"}
    end
  end

  describe "get_value/2 - nested map traversal" do
    test "traverses two-level nested map" do
      # Arrange
      data = %{
        "customer" => %{
          "name" => "Jane"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer", "name"])

      # Assert
      assert result == {:ok, "Jane"}
    end

    test "traverses three-level nested map" do
      # Arrange
      data = %{
        "order" => %{
          "customer" => %{
            "email" => "jane@example.com"
          }
        }
      }

      # Act
      result = DataAccess.get_value(data, ["order", "customer", "email"])

      # Assert
      assert result == {:ok, "jane@example.com"}
    end

    test "applies case-insensitive matching at each level" do
      # Arrange
      data = %{
        "Customer" => %{
          "NAME" => "Jane"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer", "name"])

      # Assert
      assert result == {:ok, "Jane"}
    end

    test "returns error when intermediate path not found" do
      # Arrange
      data = %{
        "customer" => %{
          "name" => "Jane"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer", "missing", "value"])

      # Assert
      assert result == {:error, {:path_not_found, ["customer", "missing", "value"]}}
    end

    test "traverses deeply nested structure (10+ levels)" do
      # Arrange
      data = %{
        "a" => %{
          "b" => %{
            "c" => %{
              "d" => %{
                "e" => %{
                  "f" => %{
                    "g" => %{
                      "h" => %{
                        "i" => %{
                          "j" => %{
                            "value" => "deeply nested"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Act
      result = DataAccess.get_value(data, ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "value"])

      # Assert
      assert result == {:ok, "deeply nested"}
    end
  end

  describe "get_value/2 - list traversal" do
    test "accesses first element in list" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "0", "price"])

      # Assert
      assert result == {:ok, "99.99"}
    end

    test "accesses second element in list" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99},
          %{"price" => 49.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "1", "price"])

      # Assert
      assert result == {:ok, "49.99"}
    end

    test "accesses nested list within map" do
      # Arrange
      data = %{
        "order" => %{
          "items" => [
            %{"name" => "Widget"},
            %{"name" => "Gadget"}
          ]
        }
      }

      # Act
      result = DataAccess.get_value(data, ["order", "items", "1", "name"])

      # Assert
      assert result == {:ok, "Gadget"}
    end

    test "returns error when index out of bounds" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "5", "price"])

      # Assert
      assert result == {:error, {:index_out_of_bounds, 5, 1}}
    end

    test "returns error for negative index" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "-1", "price"])

      # Assert
      assert result == {:error, {:invalid_index, "-1"}}
    end

    test "returns error for non-numeric index" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "abc", "price"])

      # Assert
      assert result == {:error, {:invalid_index, "abc"}}
    end

    test "returns error for decimal index" do
      # Arrange
      data = %{
        "items" => [
          %{"price" => 99.99}
        ]
      }

      # Act
      result = DataAccess.get_value(data, ["items", "1.5", "price"])

      # Assert
      assert result == {:error, {:invalid_index, "1.5"}}
    end
  end

  describe "get_value/2 - edge cases" do
    test "empty path returns the data itself" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = DataAccess.get_value(data, [])

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "returns error when path points to a map" do
      # Arrange
      data = %{
        "customer" => %{
          "name" => "Jane"
        }
      }

      # Act
      result = DataAccess.get_value(data, ["customer"])

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "returns error when path points to a list" do
      # Arrange
      data = %{
        "items" => [1, 2, 3]
      }

      # Act
      result = DataAccess.get_value(data, ["items"])

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "handles empty string value" do
      # Arrange
      data = %{"value" => ""}

      # Act
      result = DataAccess.get_value(data, ["value"])

      # Assert
      assert result == {:ok, ""}
    end

    test "handles zero as value" do
      # Arrange
      data = %{"count" => 0}

      # Act
      result = DataAccess.get_value(data, ["count"])

      # Assert
      assert result == {:ok, "0"}
    end

    test "handles very long string" do
      # Arrange
      long_string = String.duplicate("a", 10_000)
      data = %{"value" => long_string}

      # Act
      result = DataAccess.get_value(data, ["value"])

      # Assert
      assert result == {:ok, long_string}
    end

    test "handles large number" do
      # Arrange
      data = %{"value" => 9_999_999_999_999}

      # Act
      result = DataAccess.get_value(data, ["value"])

      # Assert
      assert result == {:ok, "9999999999999"}
    end
  end

  describe "normalize_key/2" do
    test "finds exact match" do
      # Arrange
      lookup_key = "name"
      available_keys = ["name", "age", "email"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, "name"}
    end

    test "finds case-insensitive match (lowercase lookup)" do
      # Arrange
      lookup_key = "name"
      available_keys = ["Name", "Age", "Email"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, "Name"}
    end

    test "finds case-insensitive match (uppercase lookup)" do
      # Arrange
      lookup_key = "NAME"
      available_keys = ["name", "age", "email"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, "name"}
    end

    test "returns error when no match found" do
      # Arrange
      lookup_key = "missing"
      available_keys = ["name", "age", "email"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:path_not_found, ["missing"]}}
    end

    test "returns error when multiple matches found" do
      # Arrange
      lookup_key = "name"
      available_keys = ["name", "Name", "age"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:ambiguous_key, "name", ["Name", "name"]}}
    end

    test "handles empty available keys" do
      # Arrange
      lookup_key = "name"
      available_keys = []

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:path_not_found, ["name"]}}
    end

    test "finds atom key match" do
      # Arrange
      lookup_key = "name"
      available_keys = [:name, :age, :email]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, :name}
    end

    test "finds atom key with case-insensitive match" do
      # Arrange
      lookup_key = "NAME"
      available_keys = [:name, :age]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, :name}
    end

    test "returns error when both atom and string key exist" do
      # Arrange
      lookup_key = "name"
      available_keys = [:name, "name"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:conflicting_key_types, "name", :name, "name"}}
    end

    test "returns error when both atom and string exist with case variants" do
      # Arrange
      lookup_key = "name"
      available_keys = [:Name, "name"]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:conflicting_key_types, "name", :Name, "name"}}
    end

    test "handles multiple atom case variants as ambiguous" do
      # Arrange
      lookup_key = "name"
      available_keys = [:name, :Name, :NAME]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:error, {:ambiguous_key, "name", [:NAME, :Name, :name]}}
    end

    test "prefers unique atom key over nothing" do
      # Arrange
      lookup_key = "age"
      available_keys = [:name, :age]

      # Act
      result = DataAccess.normalize_key(lookup_key, available_keys)

      # Assert
      assert result == {:ok, :age}
    end
  end

  describe "to_string_value/1" do
    test "returns string unchanged" do
      # Arrange
      value = "hello"

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:ok, "hello"}
    end

    test "converts integer to string" do
      # Arrange
      value = 42

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:ok, "42"}
    end

    test "converts float to string" do
      # Arrange
      value = 3.14159

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:ok, "3.14159"}
    end

    test "converts true to string" do
      # Arrange
      value = true

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:ok, "true"}
    end

    test "converts false to string" do
      # Arrange
      value = false

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:ok, "false"}
    end

    test "returns error for nil" do
      # Arrange
      value = nil

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:error, :nil_value}
    end

    test "returns error for map" do
      # Arrange
      value = %{"key" => "value"}

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "returns error for list" do
      # Arrange
      value = [1, 2, 3]

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "returns error for atom (other than true/false)" do
      # Arrange
      value = :some_atom

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:error, :unsupported_type}
    end

    test "returns error for tuple" do
      # Arrange
      value = {:ok, "result"}

      # Act
      result = DataAccess.to_string_value(value)

      # Assert
      assert result == {:error, :unsupported_type}
    end
  end
end
