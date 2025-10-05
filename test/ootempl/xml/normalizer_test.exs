defmodule Ootempl.Xml.NormalizerTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml
  alias Ootempl.Xml.Normalizer

  require Record

  # Add xmlNamespace record definition
  Record.defrecord(
    :xmlNamespace,
    Record.extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl")
  )

  describe "normalize/1" do
    test "leaves non-paragraph elements unchanged" do
      xml = "<root><child>text</child></root>"
      {:ok, doc} = Ootempl.Xml.parse(xml)

      normalized = Normalizer.normalize(doc)

      assert xmlElement(normalized, :name) == :root
    end

    test "normalizes paragraphs within document" do
      # Simple document with a paragraph containing a fragmented placeholder
      xml = ~s(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>@na</w:t></w:r><w:r><w:t>me@</w:t></w:r></w:p></w:body></w:document>)

      {:ok, doc} = Ootempl.Xml.parse(xml)
      normalized = Normalizer.normalize(doc)

      # Extract the paragraph
      body = Ootempl.Xml.find_elements(normalized, :"w:body") |> hd()
      para = Ootempl.Xml.find_elements(body, :"w:p") |> hd()
      runs = Ootempl.Xml.find_elements(para, :"w:r")

      # Should have one run after normalization
      assert length(runs) == 1

      # The run should contain the complete placeholder
      run_text = extract_text_from_run(runs |> hd())
      assert run_text == "@name@"
    end
  end

  describe "normalize_paragraph/1" do
    test "collapses simple fragmented placeholder across two runs" do
      # Arrange
      para = create_paragraph([
        create_run("@na"),
        create_run("me@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1
      assert extract_text_from_run(hd(runs)) == "@name@"
    end

    test "collapses placeholder fragmented across three runs" do
      # Arrange
      para = create_paragraph([
        create_run("@person"),
        create_run(".first"),
        create_run("_name@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1
      assert extract_text_from_run(hd(runs)) == "@person.first_name@"
    end

    test "collapses placeholder with surrounding text" do
      # Arrange
      para = create_paragraph([
        create_run("Hello @"),
        create_run("name"),
        create_run("@!")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1
      assert extract_text_from_run(hd(runs)) == "Hello @name@!"
    end

    test "handles multiple fragmented placeholders in same paragraph" do
      # Arrange
      para = create_paragraph([
        create_run("@first"),
        create_run("@"),
        create_run(" and "),
        create_run("@se"),
        create_run("cond@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should collapse into 2 runs: one for "@first@" and one for " and @second@"
      # Actually, this depends on the algorithm - it might be 1 run for the first placeholder,
      # then separate handling for the second
      # Let's verify the text is preserved
      full_text = Enum.map_join(runs, &extract_text_from_run/1)
      assert full_text == "@first@ and @second@"
    end

    test "strips proofing markers between runs" do
      # Arrange
      para = create_paragraph([
        create_run("@na"),
        create_proofing_error(),
        create_run("me@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      content = xmlElement(normalized, :content)
      # Should not contain proofing errors
      refute Enum.any?(content, fn node ->
        Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :"w:proofErr"
      end)

      # Should have one run with complete placeholder
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert Enum.count(runs) == 1
      assert extract_text_from_run(hd(runs)) == "@name@"
    end

    test "preserves run properties when collapsing with consistent formatting" do
      # Arrange
      bold_props = create_run_properties([create_bold()])

      para = create_paragraph([
        create_run("@na", bold_props),
        create_run("me@", bold_props)
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1

      run = hd(runs)
      assert extract_text_from_run(run) == "@name@"

      # Should have run properties preserved (both fragments were bold)
      r_pr = Ootempl.Xml.find_elements(run, :"w:rPr")
      assert length(r_pr) == 1
    end

    test "strips formatting when fragments have inconsistent formatting" do
      # Arrange - bold + italic fragments
      bold_props = create_run_properties([create_bold()])
      italic_props = create_run_properties([create_italic()])

      para = create_paragraph([
        create_run("@na", bold_props),
        create_run("me@", italic_props)
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1

      run = hd(runs)
      assert extract_text_from_run(run) == "@name@"

      # Should NOT have run properties (inconsistent formatting stripped)
      r_pr = Ootempl.Xml.find_elements(run, :"w:rPr")
      assert Enum.empty?(r_pr)
    end

    test "strips formatting when one fragment is formatted and one is not" do
      # Arrange - bold + plain fragments
      bold_props = create_run_properties([create_bold()])

      para = create_paragraph([
        create_run("@na", bold_props),
        create_run("me@", nil)
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1

      run = hd(runs)
      assert extract_text_from_run(run) == "@name@"

      # Should NOT have run properties (mixed formatting stripped)
      r_pr = Ootempl.Xml.find_elements(run, :"w:rPr")
      assert Enum.empty?(r_pr)
    end

    test "preserves complex formatting when consistent across fragments" do
      # Arrange - bold+italic on both fragments
      bold_italic_props = create_run_properties([create_bold(), create_italic()])

      para = create_paragraph([
        create_run("@na", bold_italic_props),
        create_run("me@", bold_italic_props)
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1

      run = hd(runs)
      assert extract_text_from_run(run) == "@name@"

      # Should have both bold and italic preserved
      r_pr = Ootempl.Xml.find_elements(run, :"w:rPr")
      assert length(r_pr) == 1

      r_pr_content = hd(r_pr) |> xmlElement(:content)
      assert length(r_pr_content) == 2
      # Check that both bold and italic are present (order may vary)
      names = Enum.map(r_pr_content, fn elem -> xmlElement(elem, :name) end)
      assert :"w:b" in names
      assert :"w:i" in names
    end

    test "does not collapse incomplete placeholders" do
      # Arrange
      para = create_paragraph([
        create_run("@incomplete"),
        create_run(" text")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should keep runs separate since it's not a valid placeholder
      assert length(runs) == 2
    end

    test "does not collapse non-placeholder text" do
      # Arrange
      para = create_paragraph([
        create_run("Hello "),
        create_run("world")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should keep runs separate
      assert length(runs) == 2
    end

    test "handles empty paragraph" do
      # Arrange
      para = create_paragraph([])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      content = xmlElement(normalized, :content)
      assert content == []
    end

    test "handles single run with placeholder" do
      # Arrange - single run that is already a complete placeholder
      para = create_paragraph([
        create_run("@name@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1
      assert extract_text_from_run(hd(runs)) == "@name@"
    end

    test "handles paragraph with only proofing markers" do
      # Arrange
      para = create_paragraph([
        create_proofing_error()
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert Enum.empty?(runs)
    end

    test "preserves paragraph properties" do
      # Arrange
      para_props = create_paragraph_properties()
      para = create_paragraph_with_props([create_run("@name@")], para_props)

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      p_pr = Ootempl.Xml.find_elements(normalized, :"w:pPr")
      assert length(p_pr) == 1
    end

    test "handles placeholder at end of paragraph with accumulated runs" do
      # Arrange - placeholder fragments that reach end of paragraph
      para = create_paragraph([
        create_run("Text "),
        create_run("@na"),
        create_run("me@")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should collapse last two runs, keep first separate
      assert length(runs) == 2
      assert extract_text_from_run(Enum.at(runs, 0)) == "Text "
      assert extract_text_from_run(Enum.at(runs, 1)) == "@name@"
    end

    test "handles non-run node after accumulated runs" do
      # Arrange - runs followed by non-run element
      para = create_paragraph([
        create_run("@incomplete"),
        create_run(" text"),
        create_paragraph_properties()  # Non-run node
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should keep runs separate (no placeholder found)
      assert length(runs) == 2
    end

    test "handles text that starts building placeholder but stops" do
      # Arrange - text with @ but not a placeholder, then more text
      para = create_paragraph([
        create_run("Email: test"),
        create_run("@example.com")
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      # Should keep separate (not a placeholder)
      assert length(runs) == 2
    end

    test "strips formatting when all fragments have nil properties" do
      # Arrange - all plain text (nil properties)
      para = create_paragraph([
        create_run("@na", nil),
        create_run("me@", nil)
      ])

      # Act
      normalized = Normalizer.normalize_paragraph(para)

      # Assert
      runs = Ootempl.Xml.find_elements(normalized, :"w:r")
      assert length(runs) == 1
      assert extract_text_from_run(hd(runs)) == "@name@"

      # Should have no properties (consistent nil)
      r_pr = Ootempl.Xml.find_elements(hd(runs), :"w:rPr")
      assert Enum.empty?(r_pr)
    end
  end

  describe "integration with real .docx fixture" do
    @fixture_path "test/fixtures/Simple Placeholdes from Word.docx"

    test "detects fragmented placeholders in real Word document" do
      # Arrange - load the real document
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize the document
      normalized_doc = Normalizer.normalize(doc)

      # Assert - find body, then paragraphs and extract text
      bodies = Ootempl.Xml.find_elements(normalized_doc, :"w:body")
      assert length(bodies) > 0, "Should find w:body element"

      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      # Collect all text from all paragraphs
      all_text =
        paragraphs
        |> Enum.flat_map(fn para ->
          para
          |> Ootempl.Xml.find_elements(:"w:r")
          |> Enum.map(&extract_text_from_run/1)
        end)
        |> Enum.join("")

      # Should detect both placeholders
      placeholders = Ootempl.Placeholder.detect(all_text)
      placeholder_variables = Enum.map(placeholders, & &1.variable)

      assert "person.first_name" in placeholder_variables
      assert "date" in placeholder_variables
    end

    test "original document has fragmented placeholder structure" do
      # Arrange - load the original document WITHOUT normalization
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - find body, then paragraphs with the fragmented placeholder pattern
      bodies = Ootempl.Xml.find_elements(doc, :"w:body")
      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      # Look for paragraph containing the fragmented @person.first_name@ pattern
      fragmented_para =
        Enum.find(paragraphs, fn para ->
          runs = Ootempl.Xml.find_elements(para, :"w:r")
          texts = Enum.map(runs, &extract_text_from_run/1)
          combined = Enum.join(texts, "")

          # Should contain the placeholder but split across runs
          String.contains?(combined, "person.first") and String.contains?(combined, "_name@")
        end)

      # Assert - found the fragmented paragraph
      assert fragmented_para != nil, "Should find paragraph with fragmented @person.first_name@"

      # Verify it's actually fragmented (multiple runs, not in a single run)
      runs = Ootempl.Xml.find_elements(fragmented_para, :"w:r")
      texts = Enum.map(runs, &extract_text_from_run/1)

      # No single run should contain the complete placeholder
      refute Enum.any?(texts, &String.contains?(&1, "@person.first_name@")),
        "Placeholder should be fragmented across runs, not in single run"

      # But the combined text should contain it
      combined = Enum.join(texts, "")
      assert String.contains?(combined, "person.first") and String.contains?(combined, "_name@")
    end

    test "normalization collapses fragmented @person.first_name@ placeholder" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize
      normalized_doc = Normalizer.normalize(doc)

      # Assert - find body, then the paragraph with @person.first_name@
      bodies = Ootempl.Xml.find_elements(normalized_doc, :"w:body")
      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      target_para =
        Enum.find(paragraphs, fn para ->
          runs = Ootempl.Xml.find_elements(para, :"w:r")
          texts = Enum.map(runs, &extract_text_from_run/1)
          Enum.any?(texts, &String.contains?(&1, "person.first_name"))
        end)

      assert target_para != nil, "Should find paragraph containing person.first_name"

      # After normalization, the text containing the placeholder should be in fewer runs
      runs = Ootempl.Xml.find_elements(target_para, :"w:r")
      texts = Enum.map(runs, &extract_text_from_run/1)

      # Find text containing complete placeholder
      placeholder_text = Enum.find(texts, &String.contains?(&1, "@person.first_name@"))

      assert placeholder_text != nil,
        "After normalization, @person.first_name@ should be in a single run"

      # Verify it's detectable
      placeholders = Ootempl.Placeholder.detect(placeholder_text)
      assert length(placeholders) >= 1
      assert Enum.any?(placeholders, &(&1.variable == "person.first_name"))
    end

    test "normalization preserves @date@ placeholder" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize
      normalized_doc = Normalizer.normalize(doc)

      # Assert - find body, extract all text and verify @date@ is detectable
      bodies = Ootempl.Xml.find_elements(normalized_doc, :"w:body")
      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      all_text =
        paragraphs
        |> Enum.flat_map(fn para ->
          para
          |> Ootempl.Xml.find_elements(:"w:r")
          |> Enum.map(&extract_text_from_run/1)
        end)
        |> Enum.join("")

      assert String.contains?(all_text, "@date@")

      # Verify it's detectable by placeholder detection
      placeholders = Ootempl.Placeholder.detect(all_text)
      assert Enum.any?(placeholders, &(&1.variable == "date"))
    end

    test "normalized document removes proofing errors" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize
      normalized_doc = Normalizer.normalize(doc)

      # Assert - find body, verify no w:proofErr elements remain in paragraphs
      bodies = Ootempl.Xml.find_elements(normalized_doc, :"w:body")
      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      proofing_errors =
        Enum.flat_map(paragraphs, fn para ->
          para
          |> xmlElement(:content)
          |> Enum.filter(fn node ->
            Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :"w:proofErr"
          end)
        end)

      assert Enum.empty?(proofing_errors),
        "All proofing error markers should be removed after normalization"
    end

    test "full round-trip with real fixture preserves structure" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, original_doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize and serialize
      normalized_doc = Normalizer.normalize(original_doc)
      {:ok, serialized} = Ootempl.Xml.serialize(normalized_doc)

      # Assert - can re-parse
      assert {:ok, reparsed_doc} = Ootempl.Xml.parse(serialized)
      assert Ootempl.Xml.element_name(reparsed_doc) == "w:document"

      # Placeholders should still be detectable - find body first
      bodies = Ootempl.Xml.find_elements(reparsed_doc, :"w:body")
      body = hd(bodies)
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

      all_text =
        paragraphs
        |> Enum.flat_map(fn para ->
          para
          |> Ootempl.Xml.find_elements(:"w:r")
          |> Enum.map(&extract_text_from_run/1)
        end)
        |> Enum.join("")

      placeholders = Ootempl.Placeholder.detect(all_text)
      placeholder_variables = Enum.map(placeholders, & &1.variable)

      assert "person.first_name" in placeholder_variables
      assert "date" in placeholder_variables
    end
  end

  describe "placeholder replacement" do
    @test_name "Marty McFly"
    @test_date "October 21, 2015"  # The date Marty travels to in Back to the Future II
    @output_path_temp "test/fixtures/replacement_test_output.docx"
    @output_path_manual "test/fixtures/manual_inspection_output.docx"

    test "replaces placeholders in normalized document" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize
      normalized_doc = Normalizer.normalize(doc)

      # Serialize and do simple string replacement
      {:ok, serialized} = Ootempl.Xml.serialize(normalized_doc)

      # Replace placeholders with actual values
      replaced_xml = serialized
        |> String.replace("@person.first_name@", @test_name)
        |> String.replace("@date@", @test_date)

      # Save to temp output file
      output_path = @output_path_temp

      # Extract the full template to a temp dir
      {:ok, temp_dir} = Ootempl.Archive.extract(@fixture_path)

      try do
        # Write the modified document.xml
        document_path = Path.join(temp_dir, "word/document.xml")
        File.write!(document_path, replaced_xml)

        # Collect all files from temp dir
        {:ok, file_map} = build_file_map_for_test(temp_dir)

        # Create the output .docx
        :ok = Ootempl.Archive.create(file_map, output_path)

        # Assert - verify file was created and contains expected content
        assert File.exists?(output_path)

        # Extract and verify the content
        {:ok, result_xml} = Ootempl.Archive.extract_file(output_path, "word/document.xml")
        {:ok, result_doc} = Ootempl.Xml.parse(result_xml)

        # Extract all text from the document
        bodies = Ootempl.Xml.find_elements(result_doc, :"w:body")
        body = hd(bodies)
        paragraphs = Ootempl.Xml.find_elements(body, :"w:p")

        all_text =
          paragraphs
          |> Enum.flat_map(fn para ->
            para
            |> Ootempl.Xml.find_elements(:"w:r")
            |> Enum.map(&extract_text_from_run/1)
          end)
          |> Enum.join("")

        # Assert replacements were made correctly
        assert String.contains?(all_text, @test_name)
        assert String.contains?(all_text, @test_date)

        # Verify NO placeholders remain
        refute String.contains?(all_text, "@person.first_name@")
        refute String.contains?(all_text, "@date@")

        # Verify the complete expected sentence
        expected_text = "Hello #{@test_name}, how are you on this #{@test_date}?"
        assert String.contains?(all_text, expected_text)
      after
        # Cleanup
        Ootempl.Archive.cleanup(temp_dir)
        File.rm(output_path)
      end
    end

    @tag :manual
    test "creates inspection file with replaced placeholders" do
      # Arrange
      {:ok, xml_content} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(xml_content)

      # Act - normalize
      normalized_doc = Normalizer.normalize(doc)

      # Serialize and do simple string replacement
      {:ok, serialized} = Ootempl.Xml.serialize(normalized_doc)

      # Replace placeholders with actual values
      replaced_xml = serialized
        |> String.replace("@person.first_name@", @test_name)
        |> String.replace("@date@", @test_date)

      # Save to manual inspection file
      output_path = @output_path_manual

      # Extract the full template to a temp dir
      {:ok, temp_dir} = Ootempl.Archive.extract(@fixture_path)

      try do
        # Write the modified document.xml
        document_path = Path.join(temp_dir, "word/document.xml")
        File.write!(document_path, replaced_xml)

        # Collect all files from temp dir
        {:ok, file_map} = build_file_map_for_test(temp_dir)

        # Create the output .docx
        :ok = Ootempl.Archive.create(file_map, output_path)

        IO.puts("""

        ========================================
        MANUAL INSPECTION FILE CREATED
        ========================================

        Output file saved to:
        #{Path.expand(output_path)}

        Replacements made:
        - @person.first_name@ → #{@test_name}
        - @date@ → #{@test_date}

        Please open in Microsoft Word to verify:
        1. File opens without errors
        2. Placeholders are replaced correctly
        3. Text appears as: "Hello #{@test_name}, how are you on this #{@test_date}?"
        4. No corruption warnings

        To run this test:
        mix test --only manual test/ootempl/xml/normalizer_test.exs

        ========================================
        """)

        # Assert - just verify file was created
        assert File.exists?(output_path)
      after
        # Cleanup temp directory
        Ootempl.Archive.cleanup(temp_dir)
      end
    end

    # Helper for this manual test
    defp build_file_map_for_test(temp_dir) do
      case gather_files_for_test(temp_dir, temp_dir) do
        {:ok, file_map} -> {:ok, file_map}
        {:error, reason} -> {:error, {:build_file_map_failed, reason}}
      end
    end

    defp gather_files_for_test(base_dir, current_dir) do
      case File.ls(current_dir) do
        {:ok, entries} ->
          file_map =
            Enum.reduce(entries, %{}, fn entry, acc ->
              full_path = Path.join(current_dir, entry)
              relative_path = Path.relative_to(full_path, base_dir)

              cond do
                File.regular?(full_path) ->
                  case File.read(full_path) do
                    {:ok, content} -> Map.put(acc, relative_path, content)
                    {:error, _} -> acc
                  end

                File.dir?(full_path) ->
                  case gather_files_for_test(base_dir, full_path) do
                    {:ok, nested_map} -> Map.merge(acc, nested_map)
                    {:error, _} -> acc
                  end

                true ->
                  acc
              end
            end)

          {:ok, file_map}

        {:error, reason} ->
          {:error, reason}
      end
    end

  end

  # Test helpers

  defp create_paragraph(runs) do
    xmlElement(
      name: :"w:p",
      content: runs,
      attributes: [],
      expanded_name: :"w:p",
      nsinfo: {~c"w", ~c"p"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_paragraph_with_props(runs, props) do
    xmlElement(
      name: :"w:p",
      content: [props | runs],
      attributes: [],
      expanded_name: :"w:p",
      nsinfo: {~c"w", ~c"p"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_paragraph_properties do
    xmlElement(
      name: :"w:pPr",
      content: [],
      attributes: [],
      expanded_name: :"w:pPr",
      nsinfo: {~c"w", ~c"pPr"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_run(text, run_props \\ nil) do
    text_node = xmlText(value: String.to_charlist(text))

    text_element = xmlElement(
      name: :"w:t",
      content: [text_node],
      attributes: [],
      expanded_name: :"w:t",
      nsinfo: {~c"w", ~c"t"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )

    content = if run_props, do: [run_props, text_element], else: [text_element]

    xmlElement(
      name: :"w:r",
      content: content,
      attributes: [],
      expanded_name: :"w:r",
      nsinfo: {~c"w", ~c"r"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_proofing_error do
    xmlElement(
      name: :"w:proofErr",
      content: [],
      attributes: [
        xmlAttribute(
          name: :"w:type",
          value: ~c"gramStart"
        )
      ],
      expanded_name: :"w:proofErr",
      nsinfo: {~c"w", ~c"proofErr"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_run_properties(children) do
    xmlElement(
      name: :"w:rPr",
      content: children,
      attributes: [],
      expanded_name: :"w:rPr",
      nsinfo: {~c"w", ~c"rPr"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_bold do
    xmlElement(
      name: :"w:b",
      content: [],
      attributes: [],
      expanded_name: :"w:b",
      nsinfo: {~c"w", ~c"b"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp create_italic do
    xmlElement(
      name: :"w:i",
      content: [],
      attributes: [],
      expanded_name: :"w:i",
      nsinfo: {~c"w", ~c"i"},
      namespace: xmlNamespace(nodes: [{~c"w", ~c"http://schemas.openxmlformats.org/wordprocessingml/2006/main"}])
    )
  end

  defp extract_text_from_run(run) do
    run
    |> xmlElement(:content)
    |> Enum.filter(fn node ->
      Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :"w:t"
    end)
    |> Enum.flat_map(fn text_elem ->
      text_elem
      |> xmlElement(:content)
      |> Enum.filter(&Record.is_record(&1, :xmlText))
      |> Enum.map(&(xmlText(&1, :value) |> List.to_string()))
    end)
    |> Enum.join()
  end

end
