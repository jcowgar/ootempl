defmodule OotemplTestHelpers do
  @moduledoc """
  Test helper functions for verifying .docx output in integration tests.

  These helpers use the public Archive API to extract and inspect generated
  .docx files during testing.
  """

  @doc """
  Extracts a specific file from a .docx archive for testing purposes.

  Uses the public `Archive.extract/1` API to extract the entire archive,
  then reads the requested file and cleans up the temp directory.

  Returns `{:ok, content}` or `{:error, reason}`.
  """
  @spec extract_file_for_test(Path.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def extract_file_for_test(docx_path, internal_path) do
    with {:ok, temp_dir} <- Ootempl.Archive.extract(docx_path),
         file_path = Path.join(temp_dir, internal_path),
         {:ok, content} <- File.read(file_path) do
      # Clean up temp directory
      Ootempl.Archive.cleanup(temp_dir)
      {:ok, content}
    else
      {:error, _reason} = error ->
        # Try to clean up if extraction succeeded but file read failed
        case Ootempl.Archive.extract(docx_path) do
          {:ok, temp_dir} -> Ootempl.Archive.cleanup(temp_dir)
          _ -> :ok
        end

        error
    end
  end

  @doc """
  Creates a .docx template with an image placeholder for testing.

  Returns a file_map suitable for `Ootempl.Archive.create/2`.
  """
  @spec create_template_with_image(map()) :: %{String.t() => binary()}
  def create_template_with_image(%{image_name: image_name, rel_id: rel_id}) do
    %{
      "word/document.xml" => """
      <?xml version="1.0"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <w:body>
          <w:p>
            <w:r>
              <w:drawing>
                <wp:inline>
                  <wp:extent cx="914400" cy="914400"/>
                  <wp:docPr descr="@image:#{image_name}@"/>
                  <a:graphic>
                    <a:graphicData>
                      <pic:pic>
                        <pic:nvPicPr>
                          <pic:cNvPr/>
                        </pic:nvPicPr>
                        <pic:blipFill>
                          <a:blip r:embed="#{rel_id}"/>
                        </pic:blipFill>
                      </pic:pic>
                    </a:graphicData>
                  </a:graphic>
                </wp:inline>
              </w:drawing>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="#{rel_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
      </Relationships>
      """,
      "[Content_Types].xml" => """
      <?xml version="1.0"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="png" ContentType="image/png"/>
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      </Types>
      """,
      "_rels/.rels" => """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
      </Relationships>
      """
    }
  end
end
