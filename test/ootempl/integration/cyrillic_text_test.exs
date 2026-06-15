defmodule Ootempl.Integration.CyrillicTextTest do
  @moduledoc """
  Tests for handling Cyrillic (Russian) text in docx templates.

  Regression test for GitHub issue #1: templates containing Russian text
  caused {:error, {:wfc_Legal_Character, {:error, {:bad_character, 1052}}}}
  because xmerl received Unicode codepoints instead of raw UTF-8 bytes.
  """

  use ExUnit.Case, async: true

  alias Ootempl.Archive

  @tmp_dir "test/fixtures/tmp_cyrillic_test"

  setup do
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      File.rm_rf!(@tmp_dir)
    end)

    :ok
  end

  describe "Cyrillic text in templates (GH issue #1)" do
    test "renders template with Russian text and placeholders" do
      docx_path = create_cyrillic_docx()
      output_path = Path.join(@tmp_dir, "output.docx")

      result =
        Ootempl.render(
          docx_path,
          %{"customer_name" => "Иван Петров", "total" => "5000₽"},
          output_path
        )

      assert result == :ok
      assert File.exists?(output_path)

      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert String.contains?(document_xml, "Мой дорогой")
        assert String.contains?(document_xml, "Иван Петров")
        assert String.contains?(document_xml, "5000₽")
        refute String.contains?(document_xml, "{{customer_name}}")
        refute String.contains?(document_xml, "{{total}}")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "renders template with only Cyrillic text and no placeholders" do
      docx_path = create_cyrillic_only_docx()
      output_path = Path.join(@tmp_dir, "output_no_placeholders.docx")

      result = Ootempl.render(docx_path, %{}, output_path)

      assert result == :ok
      assert File.exists?(output_path)

      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert String.contains?(document_xml, "Привет мир")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "renders Cyrillic replacement values into ASCII template" do
      docx_path = create_ascii_docx()
      output_path = Path.join(@tmp_dir, "output_cyrillic_values.docx")

      result =
        Ootempl.render(
          docx_path,
          %{"name" => "Александр Сергеевич"},
          output_path
        )

      assert result == :ok

      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert String.contains?(document_xml, "Александр Сергеевич")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "XML module parses Cyrillic characters directly" do
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>Мой дорогой {{customer_name}}, Ваш заказ на сумму {{total}}.</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """

      assert {:ok, _doc} = Ootempl.Xml.parse(xml_string)
    end

    test "round-trip preserves Cyrillic text" do
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <root>Привет мир! Добро пожаловать.</root>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)
      {:ok, serialized} = Ootempl.Xml.serialize(doc)

      assert String.contains?(serialized, "Привет мир")
      assert String.contains?(serialized, "Добро пожаловать")
    end

    test "validates docx with Cyrillic text" do
      docx_path = create_cyrillic_docx()

      assert :ok = Ootempl.Validator.validate_docx(docx_path)
    end

    test "loads template with Cyrillic text for batch rendering" do
      docx_path = create_cyrillic_docx()

      assert {:ok, template} = Ootempl.load(docx_path)

      output_path = Path.join(@tmp_dir, "output_loaded.docx")

      result =
        Ootempl.render(
          template,
          %{"customer_name" => "Мария", "total" => "3000₽"},
          output_path
        )

      assert result == :ok

      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert String.contains?(document_xml, "Мария")
        assert String.contains?(document_xml, "Мой дорогой")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "inspects template with Cyrillic text" do
      docx_path = create_cyrillic_docx()

      {:ok, info} = Ootempl.inspect(docx_path)

      assert length(info.placeholders) == 2

      originals = info.placeholders |> Enum.map(& &1.original) |> Enum.sort()
      assert originals == ["{{customer_name}}", "{{total}}"]
    end
  end

  # Helpers

  defp create_cyrillic_docx do
    output_path = Path.join(@tmp_dir, "cyrillic_template.docx")

    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => cyrillic_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Archive.create(file_map, output_path)
    output_path
  end

  defp create_cyrillic_only_docx do
    output_path = Path.join(@tmp_dir, "cyrillic_only.docx")

    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => cyrillic_only_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Archive.create(file_map, output_path)
    output_path
  end

  defp create_ascii_docx do
    output_path = Path.join(@tmp_dir, "ascii_template.docx")

    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => ascii_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Archive.create(file_map, output_path)
    output_path
  end

  defp cyrillic_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Мой дорогой {{customer_name}}, Ваш заказ на сумму {{total}}.</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp cyrillic_only_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Привет мир! Это документ на русском языке.</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp ascii_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Hello {{name}}, welcome!</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

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
