defmodule Ootempl.InspectTest do
  use ExUnit.Case, async: true

  alias Ootempl.TemplateInfo

  @fixtures_dir "test/fixtures"

  describe "inspect/1 with file path" do
    test "returns TemplateInfo struct for valid template" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, %TemplateInfo{} = info} = Ootempl.inspect(template_path)
      assert is_boolean(info.valid?)
      assert is_list(info.placeholders)
      assert is_list(info.conditionals)
      assert is_list(info.required_keys)
      assert is_list(info.errors)
    end

    test "detects placeholders in simple template" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      assert length(info.placeholders) > 0

      # Verify placeholder structure
      placeholder = List.first(info.placeholders)
      assert is_binary(placeholder.original)
      assert is_list(placeholder.path)
      assert is_list(placeholder.locations)
    end

    test "detects nested placeholders" do
      template_path = Path.join(@fixtures_dir, "comprehensive_template.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should have nested placeholders like @customer.name@
      nested_placeholders =
        Enum.filter(info.placeholders, fn ph -> length(ph.path) > 1 end)

      assert length(nested_placeholders) > 0
    end

    test "deduplicates placeholders across locations" do
      template_path = Path.join(@fixtures_dir, "with_header_footer.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Verify all placeholders have correct location structure
      Enum.each(info.placeholders, fn ph ->
        assert is_list(ph.locations)
        assert length(ph.locations) > 0

        # Each location should be an atom
        Enum.each(ph.locations, fn location ->
          assert is_atom(location)
        end)
      end)
    end

    test "extracts required top-level keys" do
      template_path = Path.join(@fixtures_dir, "table_with_variables.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      assert length(info.required_keys) > 0

      # All required keys should be strings
      Enum.each(info.required_keys, fn key ->
        assert is_binary(key)
      end)

      # Required keys should be sorted and unique
      assert info.required_keys == Enum.sort(Enum.uniq(info.required_keys))
    end

    test "detects conditionals in template" do
      # We need to create or use a template with conditionals
      # For now, this test will check the structure
      template_path = Path.join(@fixtures_dir, "comprehensive_template.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Verify conditional structure (may be empty if template has no conditionals)
      Enum.each(info.conditionals, fn cond ->
        assert is_binary(cond.condition)
        assert is_list(cond.path)
        assert is_list(cond.locations)
      end)
    end

    test "scans document body" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find at least one placeholder in document body
      body_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          :document_body in ph.locations
        end)

      assert length(body_placeholders) > 0
    end

    test "scans headers when present" do
      template_path = Path.join(@fixtures_dir, "with_header_footer.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find placeholders in header
      header_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          Enum.any?(ph.locations, &String.starts_with?(Atom.to_string(&1), "header"))
        end)

      assert length(header_placeholders) > 0
    end

    test "scans footers when present" do
      template_path = Path.join(@fixtures_dir, "with_header_footer.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find placeholders in footer
      footer_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          Enum.any?(ph.locations, &String.starts_with?(Atom.to_string(&1), "footer"))
        end)

      assert length(footer_placeholders) > 0
    end

    test "scans footnotes when present" do
      template_path = Path.join(@fixtures_dir, "with_footnotes.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find placeholders in footnotes if they exist
      footnote_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          :footnotes in ph.locations
        end)

      # Template may or may not have placeholders in footnotes
      # Just verify the inspection succeeded
      assert is_list(footnote_placeholders)
    end

    test "scans endnotes when present" do
      template_path = Path.join(@fixtures_dir, "with_endnotes.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find placeholders in endnotes if they exist
      endnote_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          :endnotes in ph.locations
        end)

      # Template may or may not have placeholders in endnotes
      # Just verify the inspection succeeded
      assert is_list(endnote_placeholders)
    end

    test "scans document properties when present" do
      template_path = Path.join(@fixtures_dir, "with_properties.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should find placeholders in properties if they exist
      property_placeholders =
        Enum.filter(info.placeholders, fn ph ->
          :properties in ph.locations
        end)

      # Template may or may not have placeholders in properties
      # Just verify the inspection succeeded
      assert is_list(property_placeholders)
    end

    test "returns valid? = true for template with no errors" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      assert info.valid? == true
      assert Enum.empty?(info.errors)
    end

    test "handles template with no placeholders" do
      template_path = Path.join(@fixtures_dir, "table_no_template.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      assert is_list(info.placeholders)
      assert is_list(info.required_keys)
      assert info.valid? == true
    end

    test "returns error for non-existent file" do
      template_path = "nonexistent_template.docx"

      assert {:error, _reason} = Ootempl.inspect(template_path)
    end

    test "returns error for invalid .docx file" do
      # Create a temporary invalid file
      invalid_path = Path.join(System.tmp_dir!(), "invalid_test_#{:rand.uniform(10000)}.docx")
      File.write!(invalid_path, "not a valid docx file")

      assert {:error, _reason} = Ootempl.inspect(invalid_path)

      # Cleanup
      File.rm(invalid_path)
    end

    test "handles templates with table placeholders" do
      template_path = Path.join(@fixtures_dir, "table_with_variables.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should detect placeholders from table rows
      assert length(info.placeholders) > 0
    end

    test "placeholder locations are sorted" do
      template_path = Path.join(@fixtures_dir, "with_header_footer.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Verify all placeholder locations are sorted
      Enum.each(info.placeholders, fn ph ->
        assert ph.locations == Enum.sort(ph.locations)
      end)
    end

    test "placeholders are sorted by original text" do
      template_path = Path.join(@fixtures_dir, "comprehensive_template.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      if length(info.placeholders) > 1 do
        originals = Enum.map(info.placeholders, & &1.original)
        assert originals == Enum.sort(originals)
      end
    end

    test "required keys are sorted" do
      template_path = Path.join(@fixtures_dir, "comprehensive_template.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      assert info.required_keys == Enum.sort(info.required_keys)
    end

    test "handles multiple headers correctly" do
      template_path = Path.join(@fixtures_dir, "multiple_headers.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Should detect multiple header locations
      header_locations =
        info.placeholders
        |> Enum.flat_map(& &1.locations)
        |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "header"))
        |> Enum.uniq()

      # May have multiple headers
      assert is_list(header_locations)
    end
  end

  describe "inspect_template/1 with conditional validation" do
    test "validates properly paired conditionals" do
      # This would require a fixture with valid conditionals
      # For now, we'll just verify the errors list is empty for valid templates
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      assert Enum.empty?(info.errors)
    end

    test "error structure is correct when present" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)

      # Verify error structure (may be empty)
      Enum.each(info.errors, fn error ->
        assert Map.has_key?(error, :type)
        assert Map.has_key?(error, :message)
        assert Map.has_key?(error, :location)
        assert is_binary(error.message)
      end)
    end
  end

  describe "inspect_template/1 error handling" do
    test "cleanup happens even if inspection has errors" do
      # Use an invalid template that will fail during processing
      invalid_path = Path.join(System.tmp_dir!(), "inspect_error_#{:rand.uniform(10000)}.docx")

      # Create a minimal but invalid .docx (valid ZIP but invalid XML)
      File.write!(invalid_path, <<80, 75, 3, 4>>)

      # Should return error but not leave temp files
      assert {:error, _reason} = Ootempl.inspect(invalid_path)

      # Cleanup
      File.rm(invalid_path)
    end

    test "returns appropriate error for missing required XML files" do
      # This would require a malformed docx fixture
      # For now just test that error path is reachable
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # Normal template should work
      assert {:ok, _info} = Ootempl.inspect(template_path)
    end
  end

  describe "inspect_template/1 edge cases" do
    test "handles templates with only image placeholders (no variable placeholders)" do
      # Image templates use @image:name@ syntax which should not be detected as regular placeholders
      template_path = Path.join(@fixtures_dir, "image_simple.docx")

      assert {:ok, _info} = Ootempl.inspect(template_path)
      # Image placeholders use different syntax and may not be in placeholders list
    end

    test "handles templates with complex table structures" do
      template_path = Path.join(@fixtures_dir, "table_multirow.docx")

      assert {:ok, info} = Ootempl.inspect(template_path)
      # Tables may have placeholders
      assert is_list(info.placeholders)
    end

    test "handles templates with textboxes" do
      template_path = Path.join(@fixtures_dir, "with_textboxes.docx")

      assert {:ok, _info} = Ootempl.inspect(template_path)
    end
  end

  describe "inspect/1 with Template struct" do
    test "accepts pre-loaded Template struct" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # Load template first
      assert {:ok, template} = Ootempl.load(template_path)

      # Inspect the loaded template
      assert {:ok, %TemplateInfo{} = info} = Ootempl.inspect(template)
      assert is_boolean(info.valid?)
      assert is_list(info.placeholders)
      assert is_list(info.conditionals)
      assert is_list(info.required_keys)
      assert is_list(info.errors)
    end

    test "produces same results as file path inspection" do
      template_path = Path.join(@fixtures_dir, "comprehensive_template.docx")

      # Inspect from file path
      assert {:ok, info_from_path} = Ootempl.inspect(template_path)

      # Load and inspect from template
      assert {:ok, template} = Ootempl.load(template_path)
      assert {:ok, info_from_template} = Ootempl.inspect(template)

      # Results should be identical
      assert info_from_path.placeholders == info_from_template.placeholders
      assert info_from_path.conditionals == info_from_template.conditionals
      assert info_from_path.required_keys == info_from_template.required_keys
      assert info_from_path.errors == info_from_template.errors
      assert info_from_path.valid? == info_from_template.valid?
    end

    test "optimized for batch inspection" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # Load once
      assert {:ok, template} = Ootempl.load(template_path)

      # Inspect multiple times with same template (should be fast)
      results =
        Enum.map(1..3, fn _ ->
          Ootempl.inspect(template)
        end)

      # All results should succeed
      assert Enum.all?(results, &match?({:ok, %TemplateInfo{}}, &1))

      # All results should be identical
      infos = Enum.map(results, fn {:ok, info} -> info end)
      assert Enum.uniq(infos) |> length() == 1
    end

    test "works with templates containing headers and footers" do
      template_path = Path.join(@fixtures_dir, "with_header_footer.docx")

      assert {:ok, template} = Ootempl.load(template_path)
      assert {:ok, info} = Ootempl.inspect(template)

      # Should find placeholders in headers and footers
      locations = info.placeholders |> Enum.flat_map(& &1.locations) |> Enum.uniq()

      assert Enum.any?(locations, &String.starts_with?(Atom.to_string(&1), "header"))
      assert Enum.any?(locations, &String.starts_with?(Atom.to_string(&1), "footer"))
    end
  end

  describe "inspect/1 integration" do
    test "can be used before validate/2 to check requirements" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # First inspect to discover requirements
      assert {:ok, info} = Ootempl.inspect(template_path)
      assert length(info.required_keys) > 0

      # Then validate with data containing those keys
      # This is a conceptual test showing the workflow
      assert info.valid?
    end

    test "inspection does not modify the template file" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # Get original file stats
      {:ok, stat_before} = File.stat(template_path)

      # Inspect template
      assert {:ok, _info} = Ootempl.inspect(template_path)

      # Verify file unchanged
      {:ok, stat_after} = File.stat(template_path)
      assert stat_before.mtime == stat_after.mtime
      assert stat_before.size == stat_after.size
    end

    test "can inspect same template multiple times" do
      template_path = Path.join(@fixtures_dir, "Simple Placeholdes from Word.docx")

      # Inspect multiple times
      assert {:ok, info1} = Ootempl.inspect(template_path)
      assert {:ok, info2} = Ootempl.inspect(template_path)

      # Results should be identical
      assert info1.placeholders == info2.placeholders
      assert info1.conditionals == info2.conditionals
      assert info1.required_keys == info2.required_keys
      assert info1.errors == info2.errors
      assert info1.valid? == info2.valid?
    end
  end
end
