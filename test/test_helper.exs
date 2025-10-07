ExUnit.start()

# Load test support modules
Code.require_file("support/fixture_helper.ex", __DIR__)

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
end
