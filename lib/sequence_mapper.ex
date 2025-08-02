defmodule PipeTrace do
  @moduledoc """
  Main module for generating sequence diagrams from Elixir controller code.

  This module provides a high-level interface for analyzing Elixir controller
  functions and generating Mermaid sequence diagrams that show the flow of
  function calls between different modules.

  ## Examples

      iex> PipeTrace.generate_diagram("test/fixtures/fake_controller.ex", :create)
      :ok

  The module combines the functionality of `PipeTrace.Trace` and `PipeTrace.Mermaid`
  to provide a complete workflow from source code analysis to diagram generation.
  """

  alias PipeTrace.Trace
  alias PipeTrace.Mermaid

  @doc """
  Generates a sequence diagram from a controller function.

  This is the main entry point for generating sequence diagrams. It takes a
  controller file path and function name, extracts the function calls, and
  generates a Mermaid sequence diagram showing the flow between modules.

  ## Parameters

    - `controller_module` - The path to the controller source file
    - `action` - The name of the function to analyze (as an atom)

  ## Returns

    - `:ok` - When the diagram is successfully generated and saved

  ## Examples

      iex> PipeTrace.generate_diagram("test/fixtures/fake_controller.ex", :create)
      :ok

  """
  @spec generate_diagram(String.t(), atom()) :: :ok
  def generate_diagram(controller_module, action) do
    controller_module
    |> Trace.from_source_file(action)
    |> Mermaid.generate()
  end
end
