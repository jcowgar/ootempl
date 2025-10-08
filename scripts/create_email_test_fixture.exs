#!/usr/bin/env elixir

# Create the email test fixture with new {{}} syntax

defmodule EmailFixtureCreator do
  def create do
    # Use a simple base template
    base_path = "test/fixtures/Simple Placeholdes from Word.docx"
    output_path = "test/fixtures/Simple Placeholders with Email Addresses.docx"

    # Copy the base template
    File.cp!(base_path, output_path)

    # Extract
    temp_dir = Path.join(System.tmp_dir!(), "email_fixture_#{:rand.uniform(999999)}")
    File.mkdir_p!(temp_dir)

    System.cmd("unzip", ["-q", "-d", temp_dir, output_path])

    # Create the new document content with email addresses
    doc_xml = """
    <?xml version="1.0"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t xml:space="preserve">Hello </w:t></w:r>
          <w:r><w:rPr><w:b/></w:rPr><w:t>{{person.first_name}}</w:t></w:r>
          <w:r><w:t xml:space="preserve">, (that should be bolded) how are you on this </w:t></w:r>
          <w:r><w:rPr><w:i/></w:rPr><w:t>{{date}}</w:t></w:r>
          <w:r><w:t xml:space="preserve"> (that should be italicized)?</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Once again, here is the date: {{date}} (that should not be formatted).</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t xml:space="preserve">This document goes out to someone@something.com, willy@wonka.com, and &lt;nobody@nowhere.com&gt; (these are not placeholders).</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>This is a list of not placeholders:</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>    - someone@somewhere.com</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>    - noone@nothing.com</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>    - willy@wonka.com</w:t></w:r>
        </w:p>
        <w:sectPr>
          <w:pgSz w:w="12240" w:h="15840"/>
          <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
        </w:sectPr>
      </w:body>
    </w:document>
    """

    # Write the document
    doc_path = Path.join(temp_dir, "word/document.xml")
    File.write!(doc_path, doc_xml)

    # Repackage
    abs_output = Path.expand(output_path)
    if File.exists?(abs_output), do: File.rm!(abs_output)

    original_dir = File.cwd!()
    File.cd!(temp_dir)

    {_output, 0} = System.cmd("zip", ["-r", "-q", abs_output, "."], stderr_to_stdout: true)

    File.cd!(original_dir)
    File.rm_rf!(temp_dir)

    IO.puts("✓ Created: #{output_path}")
  end
end

EmailFixtureCreator.create()
