defmodule PipeTrace.Trace do
  @moduledoc """
  Performs static analysis of Elixir source code to extract function call sequences.

  This module analyzes Elixir source files and extracts the sequence of function
  calls from specific functions, particularly focusing on pipe operators and
  module function calls.

  ## Examples

      iex> PipeTrace.Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      ["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]

  The module can handle various Elixir constructs including:
  - Pipe operators (`|>`)
  - Module function calls (`Module.function`)
  - Basic function calls
  """

  @doc """
  Extracts function calls from a source file for a specific function.

  Reads an Elixir source file, parses it into an AST, and extracts all function
  calls from the specified function. This is particularly useful for analyzing
  controller actions and their dependencies.

  ## Parameters

    - `path` - The path to the Elixir source file
    - `action` - The name of the function to analyze (as an atom)

  ## Returns

    - `[String.t()]` - A list of function call strings extracted from the function

  ## Examples

      iex> PipeTrace.Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      ["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]

  """
  @spec from_source_file(String.t(), atom()) :: {String.t(), [String.t()]}
  def from_source_file(path, action) do
    case File.read(path) do
      {:ok, source} ->
        {:ok, ast} = Code.string_to_quoted(source)
        module_name = extract_module_name(ast)
        calls = find_function_calls(ast, action)
        {module_name, calls}
      
      {:error, _reason} ->
        {"UnknownModule", []}
    end
  end

  @doc false
  @spec extract_module_name(Macro.t()) :: String.t()
  defp extract_module_name(ast) do
    Macro.prewalk(ast, "UnknownModule", fn
      {:defmodule, _, [{:__aliases__, _, module_parts}, [do: _]]} = node, _ ->
        module_name = Enum.join(module_parts, ".")
        {node, module_name}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  @doc false
  @spec find_function_calls(Macro.t(), atom()) :: [String.t()]
  defp find_function_calls(ast, action_name) do
    Macro.prewalk(ast, [], fn
      {:def, _, [{^action_name, _, _}, [do: body]]} = node, _ ->
        calls = extract_calls(body)
        {node, calls}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  @doc false
  @spec extract_calls(any()) :: [String.t()]
  defp extract_calls({:|>, _, [left, right]}) do
    # For pipe operator, we need to extract all function calls in the chain
    left_calls = extract_calls(left)
    right_calls = extract_calls(right)
    left_calls ++ right_calls
  end

  @doc false
  @spec extract_calls(any()) :: [String.t()]
  defp extract_calls({{:., _, [module, function]}, _, _}) do
    # This is a module.function call
    module_name = Macro.to_string(module)
    function_name = Macro.to_string(function)
    ["#{module_name}.#{function_name}"]
  end

  @doc false
  @spec extract_calls(any()) :: [String.t()]
  defp extract_calls({:params, _, _}) do
    # Skip params as it's not a function call
    []
  end

  @doc false
  @spec extract_calls(any()) :: [String.t()]
  defp extract_calls({left, right}) when is_tuple(left) and is_tuple(right) do
    [Macro.to_string(left), Macro.to_string(right)]
  end

  @doc false
  @spec extract_calls(any()) :: [String.t()]
  defp extract_calls(ast), do: [Macro.to_string(ast)]
end
