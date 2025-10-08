#!/usr/bin/env elixir

# Script to create .docx templates with image placeholders
# This creates templates by modifying existing templates to include images with alt text markers

defmodule TemplateCreator do
  @moduledoc """
  Creates .docx templates with image placeholders for testing.
  """

  def create_simple_image_template do
    IO.puts("Creating simple image template...")

    # Start with a simple template
    base_template = "test/fixtures/Simple Placeholders.docx"
    output_path = "test/fixtures/image_simple.docx"

    # Copy the base template
    File.cp!(base_template, output_path)

    # Extract it
    extract_dir = "test/fixtures/tmp_image_simple"
    File.mkdir_p!(extract_dir)

    {:ok, files} = :zip.unzip(String.to_charlist(output_path), cwd: String.to_charlist(extract_dir))
    IO.puts("Extracted #{length(files)} files")

    # Read document.xml
    doc_path = Path.join(extract_dir, "word/document.xml")
    {:ok, doc_content} = File.read(doc_path)

    # Add an image placeholder to the document
    # We'll insert it before the closing </w:body> tag
    image_xml = """
        <w:p>
          <w:pPr>
            <w:pStyle w:val="Normal"/>
          </w:pPr>
          <w:r>
            <w:t>Logo:</w:t>
          </w:r>
        </w:p>
        <w:p>
          <w:pPr>
            <w:pStyle w:val="Normal"/>
          </w:pPr>
          <w:r>
            <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0">
                <wp:extent cx="2000000" cy="1500000"/>
                <wp:effectExtent l="0" t="0" r="0" b="0"/>
                <wp:docPr id="1" name="Image 1" descr="{{image:logo}}"/>
                <wp:cNvGraphicFramePr>
                  <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                </wp:cNvGraphicFramePr>
                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:nvPicPr>
                        <pic:cNvPr id="1" name="Image 1"/>
                        <pic:cNvPicPr/>
                      </pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="rId5" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                        <a:stretch>
                          <a:fillRect/>
                        </a:stretch>
                      </pic:blipFill>
                      <pic:spPr>
                        <a:xfrm>
                          <a:off x="0" y="0"/>
                          <a:ext cx="2000000" cy="1500000"/>
                        </a:xfrm>
                        <a:prstGeom prst="rect">
                          <a:avLst/>
                        </a:prstGeom>
                      </pic:spPr>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>
    """

    # Insert before </w:body>
    modified_content = String.replace(doc_content, "</w:body>", "#{image_xml}</w:body>", global: false)
    File.write!(doc_path, modified_content)

    # Ensure media directory exists
    media_dir = Path.join(extract_dir, "word/media")
    File.mkdir_p!(media_dir)

    # Copy a placeholder image
    File.cp!("test/fixtures/images/test.png", Path.join(media_dir, "image1.png"))

    # Update relationships file to include the image
    rels_path = Path.join(extract_dir, "word/_rels/document.xml.rels")

    if File.exists?(rels_path) do
      {:ok, rels_content} = File.read(rels_path)

      # Add image relationship if not already present
      if !String.contains?(rels_content, "rId5") do
        image_rel = """
          <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
        """

        modified_rels = String.replace(rels_content, "</Relationships>", "#{image_rel}</Relationships>", global: false)
        File.write!(rels_path, modified_rels)
      end
    end

    # Update content types to include PNG
    content_types_path = Path.join(extract_dir, "[Content_Types].xml")

    if File.exists?(content_types_path) do
      {:ok, types_content} = File.read(content_types_path)

      if !String.contains?(types_content, "Extension=\"png\"") do
        png_type = ~s(<Default Extension="png" ContentType="image/png"/>)
        modified_types = String.replace(types_content, "</Types>", "#{png_type}</Types>", global: false)
        File.write!(content_types_path, modified_types)
      end
    end

    # Repackage the template
    repackage_template(extract_dir, output_path)

    # Cleanup
    File.rm_rf!(extract_dir)

    IO.puts("Created: #{output_path}")
  end

  def create_multiple_images_template do
    IO.puts("Creating multiple images template...")

    base_template = "test/fixtures/Simple Placeholders.docx"
    output_path = "test/fixtures/image_multiple.docx"

    File.cp!(base_template, output_path)

    extract_dir = "test/fixtures/tmp_image_multiple"
    File.mkdir_p!(extract_dir)

    {:ok, _files} = :zip.unzip(String.to_charlist(output_path), cwd: String.to_charlist(extract_dir))

    doc_path = Path.join(extract_dir, "word/document.xml")
    {:ok, doc_content} = File.read(doc_path)

    # Add multiple image placeholders
    images_xml = """
        <w:p>
          <w:pPr><w:pStyle w:val="Normal"/></w:pPr>
          <w:r><w:t>Logo:</w:t></w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0">
                <wp:extent cx="2000000" cy="1500000"/>
                <wp:effectExtent l="0" t="0" r="0" b="0"/>
                <wp:docPr id="1" name="Image 1" descr="{{image:logo}}"/>
                <wp:cNvGraphicFramePr>
                  <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                </wp:cNvGraphicFramePr>
                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:nvPicPr><pic:cNvPr id="1" name="Image 1"/><pic:cNvPicPr/></pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="rId5" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                        <a:stretch><a:fillRect/></a:stretch>
                      </pic:blipFill>
                      <pic:spPr>
                        <a:xfrm><a:off x="0" y="0"/><a:ext cx="2000000" cy="1500000"/></a:xfrm>
                        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                      </pic:spPr>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>
        <w:p>
          <w:pPr><w:pStyle w:val="Normal"/></w:pPr>
          <w:r><w:t>Photo:</w:t></w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0">
                <wp:extent cx="1500000" cy="1500000"/>
                <wp:effectExtent l="0" t="0" r="0" b="0"/>
                <wp:docPr id="2" name="Image 2" descr="{{image:photo}}"/>
                <wp:cNvGraphicFramePr>
                  <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                </wp:cNvGraphicFramePr>
                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:nvPicPr><pic:cNvPr id="2" name="Image 2"/><pic:cNvPicPr/></pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="rId6" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                        <a:stretch><a:fillRect/></a:stretch>
                      </pic:blipFill>
                      <pic:spPr>
                        <a:xfrm><a:off x="0" y="0"/><a:ext cx="1500000" cy="1500000"/></a:xfrm>
                        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                      </pic:spPr>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>
    """

    modified_content = String.replace(doc_content, "</w:body>", "#{images_xml}</w:body>", global: false)
    File.write!(doc_path, modified_content)

    # Setup media files
    media_dir = Path.join(extract_dir, "word/media")
    File.mkdir_p!(media_dir)
    File.cp!("test/fixtures/images/test.png", Path.join(media_dir, "image1.png"))
    File.cp!("test/fixtures/images/test.jpg", Path.join(media_dir, "image2.jpg"))

    # Update relationships
    rels_path = Path.join(extract_dir, "word/_rels/document.xml.rels")

    if File.exists?(rels_path) do
      {:ok, rels_content} = File.read(rels_path)

      image_rels = """
        <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
        <Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image2.jpg"/>
      """

      modified_rels = String.replace(rels_content, "</Relationships>", "#{image_rels}</Relationships>", global: false)
      File.write!(rels_path, modified_rels)
    end

    # Update content types
    content_types_path = Path.join(extract_dir, "[Content_Types].xml")

    if File.exists?(content_types_path) do
      {:ok, types_content} = File.read(content_types_path)
      png_type = ~s(<Default Extension="png" ContentType="image/png"/>)
      jpg_type = ~s(<Default Extension="jpg" ContentType="image/jpeg"/>)

      modified_types =
        types_content
        |> maybe_add_type("png", png_type)
        |> maybe_add_type("jpg", jpg_type)

      File.write!(content_types_path, modified_types)
    end

    repackage_template(extract_dir, output_path)
    File.rm_rf!(extract_dir)

    IO.puts("Created: #{output_path}")
  end

  def create_image_with_variables_template do
    IO.puts("Creating image with variables template...")

    base_template = "test/fixtures/Simple Placeholders.docx"
    output_path = "test/fixtures/image_with_variables.docx"

    File.cp!(base_template, output_path)

    extract_dir = "test/fixtures/tmp_image_vars"
    File.mkdir_p!(extract_dir)

    {:ok, _files} = :zip.unzip(String.to_charlist(output_path), cwd: String.to_charlist(extract_dir))

    doc_path = Path.join(extract_dir, "word/document.xml")
    {:ok, doc_content} = File.read(doc_path)

    # Add image and keep existing variable placeholders
    image_xml = """
        <w:p>
          <w:pPr><w:pStyle w:val="Normal"/></w:pPr>
          <w:r><w:t>Company Logo:</w:t></w:r>
        </w:p>
        <w:p>
          <w:r>
            <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0">
                <wp:extent cx="1800000" cy="1800000"/>
                <wp:effectExtent l="0" t="0" r="0" b="0"/>
                <wp:docPr id="1" name="Logo" descr="{{image:company_logo}}"/>
                <wp:cNvGraphicFramePr>
                  <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                </wp:cNvGraphicFramePr>
                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:nvPicPr><pic:cNvPr id="1" name="Logo"/><pic:cNvPicPr/></pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="rId5" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                        <a:stretch><a:fillRect/></a:stretch>
                      </pic:blipFill>
                      <pic:spPr>
                        <a:xfrm><a:off x="0" y="0"/><a:ext cx="1800000" cy="1800000"/></a:xfrm>
                        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                      </pic:spPr>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>
    """

    modified_content = String.replace(doc_content, "</w:body>", "#{image_xml}</w:body>", global: false)
    File.write!(doc_path, modified_content)

    # Setup media
    media_dir = Path.join(extract_dir, "word/media")
    File.mkdir_p!(media_dir)
    File.cp!("test/fixtures/images/test.png", Path.join(media_dir, "image1.png"))

    # Update relationships
    rels_path = Path.join(extract_dir, "word/_rels/document.xml.rels")

    if File.exists?(rels_path) do
      {:ok, rels_content} = File.read(rels_path)

      image_rel =
        ~s(<Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>)

      modified_rels = String.replace(rels_content, "</Relationships>", "#{image_rel}</Relationships>", global: false)
      File.write!(rels_path, modified_rels)
    end

    # Update content types
    content_types_path = Path.join(extract_dir, "[Content_Types].xml")

    if File.exists?(content_types_path) do
      {:ok, types_content} = File.read(content_types_path)
      png_type = ~s(<Default Extension="png" ContentType="image/png"/>)
      modified_types = maybe_add_type(types_content, "png", png_type)
      File.write!(content_types_path, modified_types)
    end

    repackage_template(extract_dir, output_path)
    File.rm_rf!(extract_dir)

    IO.puts("Created: #{output_path}")
  end

  defp maybe_add_type(content, extension, type_xml) do
    if String.contains?(content, "Extension=\"#{extension}\"") do
      content
    else
      String.replace(content, "</Types>", "#{type_xml}</Types>", global: false)
    end
  end

  defp repackage_template(extract_dir, output_path) do
    # Get all files in the directory, including hidden ones
    all_files = collect_all_files(extract_dir, extract_dir)

    # Create the ZIP archive
    {:ok, {_filename, zip_data}} = :zip.create(~c"output.zip", all_files, [:memory])
    File.write!(output_path, zip_data)
  end

  defp collect_all_files(base_dir, current_dir) do
    case File.ls(current_dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, &collect_entry(base_dir, current_dir, &1))

      {:error, _} ->
        []
    end
  end

  defp collect_entry(base_dir, current_dir, entry) do
    full_path = Path.join(current_dir, entry)

    cond do
      File.regular?(full_path) ->
        relative = Path.relative_to(full_path, base_dir)
        [{String.to_charlist(relative), File.read!(full_path)}]

      File.dir?(full_path) ->
        collect_all_files(base_dir, full_path)

      true ->
        []
    end
  end
end

# Create all templates
TemplateCreator.create_simple_image_template()
TemplateCreator.create_multiple_images_template()
TemplateCreator.create_image_with_variables_template()

IO.puts("\n✓ All image templates created successfully!")
IO.puts("  - test/fixtures/image_simple.docx")
IO.puts("  - test/fixtures/image_multiple.docx")
IO.puts("  - test/fixtures/image_with_variables.docx")
