defmodule PipeTrace.Trace do
  @moduledoc """
  Performs static analysis of Elixir source code to extract function call sequences.

  This module analyzes Elixir source files and extracts the sequence of function
  calls from specific functions, particularly focusing on pipe operators and
  module function calls. It now performs recursive analysis to find all nested
  function calls based entirely on AST analysis.

  ## Examples

      iex> PipeTrace.Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      ["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]

  The module can handle various Elixir constructs including:
  - Pipe operators (`|>`)
  - Module function calls (`Module.function`)
  - Basic function calls
  - Recursive function call analysis based on AST
  """

  @doc """
  Extracts function call pairs (caller, callee) from a source file for a specific function.
  Returns a tuple with the module name and a list of {caller, {callee, function}} pairs.
  """
  @spec from_source_file(String.t(), atom()) :: {String.t(), [{String.t(), {String.t(), String.t()}}]}
  def from_source_file(path, action) do
    case File.read(path) do
      {:ok, source} ->
        {:ok, ast} = Code.string_to_quoted(source)
        module_name = extract_module_name(ast)
        module_map = build_complete_module_map()
        pairs = find_call_pairs_recursive(ast, action, module_name, module_map)
        {module_name, pairs}
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
  @spec build_module_map(Macro.t()) :: %{String.t() => %{atom() => Macro.t()}}
  defp build_module_map(ast) do
    Macro.prewalk(ast, %{}, fn
      {:defmodule, _, [{:__aliases__, _, module_parts}, [do: module_body]]} = node, acc ->
        module_name = Enum.join(module_parts, ".")
        functions = extract_functions_from_module(module_body)
        new_acc = Map.put(acc, module_name, functions)
        {node, new_acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  @doc false
  @spec extract_functions_from_module(Macro.t()) :: %{atom() => Macro.t()}
  defp extract_functions_from_module(module_body) do
    Macro.prewalk(module_body, %{}, fn
      {:def, _, [{function_name, _, _}, [do: function_body]]} = node, acc ->
        new_acc = Map.put(acc, function_name, function_body)
        {node, new_acc}

      node, acc ->
        {node, acc}
    end)
    |> elem(1)
  end

  @doc false
  @spec find_function_calls_recursive(Macro.t(), atom(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp find_function_calls_recursive(ast, action_name, acc, module_map) do
    action_atom = action_name |> to_string() |> String.to_atom()
    
    Macro.prewalk(ast, acc, fn
      {:def, _, [{^action_atom, _, _}, [do: body]]} = node, calls ->
        new_calls = extract_calls_recursive(body, calls, module_map)
        {node, new_calls}

      {:def, _, [{_func_name, _, _}, [do: _body]]} = node, calls ->
        {node, calls}

      node, calls ->
        {node, calls}
    end)
    |> elem(1)
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive({:|>, _, [left, right]}, acc, module_map) do
    # For pipe operator, extract calls from both sides
    left_calls = extract_calls_recursive(left, acc, module_map)
    right_calls = extract_calls_recursive(right, left_calls, module_map)
    right_calls
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive({{:., _, [module, function]}, _, _args}, acc, module_map) do
    # This is a module.function call
    module_name = Macro.to_string(module)
    function_atom = function |> to_string() |> String.to_atom()
    call_string = "#{module_name}.#{function_atom}"

    # Add this call to the accumulator
    new_acc = acc ++ [call_string]

    # Look up the function in our module map and analyze it recursively
    case get_function_body(module_name, function_atom, module_map) do
      {:ok, function_body} ->
        nested_calls = extract_calls_recursive(function_body, [], module_map)
        new_acc ++ nested_calls

      :not_found ->
        new_acc
    end
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive({:params, _, _}, acc, _module_map) do
    # Skip params as it's not a function call
    acc
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive({left, right}, acc, module_map) when is_tuple(left) and is_tuple(right) do
    # Handle tuples by analyzing both sides
    left_calls = extract_calls_recursive(left, acc, module_map)
    extract_calls_recursive(right, left_calls, module_map)
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive(ast, acc, module_map) when is_list(ast) do
    # Handle lists by analyzing each element
    Enum.reduce(ast, acc, fn element, acc_element ->
      extract_calls_recursive(element, acc_element, module_map)
    end)
  end

  @doc false
  @spec extract_calls_recursive(any(), [String.t()], %{String.t() => %{atom() => Macro.t()}}) :: [String.t()]
  defp extract_calls_recursive(ast, acc, _module_map) do
    # For any other AST node, try to convert to string and add if it looks like a function call
    string_rep = Macro.to_string(ast)
    if String.contains?(string_rep, ".") and String.contains?(string_rep, "(") do
      acc ++ [string_rep]
    else
      acc
    end
  end

  @doc false
  @spec get_function_body(String.t(), atom(), %{String.t() => %{atom() => Macro.t()}}) :: {:ok, Macro.t()} | :not_found
  defp get_function_body(module_name, function_name, module_map) do
    case Map.get(module_map, module_name) do
      nil -> :not_found
      functions -> 
        case Map.get(functions, function_name) do
          nil -> :not_found
          body -> {:ok, body}
        end
    end
  end

  @doc false
  @spec build_complete_module_map() :: %{String.t() => %{atom() => Macro.t()}}
  defp build_complete_module_map() do
    # Find all .ex files in the project
    ex_files = find_ex_files()
    
    # Build module map from all files
    Enum.reduce(ex_files, %{}, fn file_path, acc ->
      case File.read(file_path) do
        {:ok, source} ->
          {:ok, ast} = Code.string_to_quoted(source)
          module_map = build_module_map(ast)
          Map.merge(acc, module_map)
        
        {:error, _reason} ->
          acc
      end
    end)
  end

  @doc false
  @spec find_ex_files() :: [String.t()]
  defp find_ex_files() do
    # Find all .ex files in common directories
    directories = ["lib", "test", "test/fixtures"]
    
    Enum.flat_map(directories, fn dir ->
      if File.dir?(dir) do
        Path.wildcard("#{dir}/**/*.ex")
      else
        []
      end
    end)
  end

  # Keep the old functions for backward compatibility
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
    # Each call in the pipe comes from the controller, not from the previous function
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

  @doc false
  @spec find_call_pairs_recursive(Macro.t(), atom(), String.t(), %{String.t() => %{atom() => Macro.t()}}) :: [{String.t(), {String.t(), String.t()}}]
  defp find_call_pairs_recursive(ast, action_name, caller, module_map) do
    action_atom = action_name |> to_string() |> String.to_atom()
    Macro.prewalk(ast, [], fn
      {:def, _, [{^action_atom, _, _}, [do: body]]} = node, pairs ->
        new_pairs = extract_call_pairs_recursive(body, caller, module_map, pairs)
        {node, new_pairs}
      node, pairs ->
        {node, pairs}
    end)
    |> elem(1)
  end

  @doc false
  @spec extract_call_pairs_recursive(any(), String.t(), %{String.t() => %{atom() => Macro.t()}}, [{String.t(), {String.t(), String.t()}}]) :: [{String.t(), {String.t(), String.t()}}]
  defp extract_call_pairs_recursive({:|>, _, [left, right]}, caller, module_map, pairs) do
    # For pipe operator, both calls are from the same caller
    left_pairs = extract_call_pairs_recursive(left, caller, module_map, pairs)
    extract_call_pairs_recursive(right, caller, module_map, left_pairs)
  end

  defp extract_call_pairs_recursive({{:., _, [module, function]}, _, _args}, caller, module_map, pairs) do
    # This is a module.function call
    module_name = Macro.to_string(module)
    function_name = function |> to_string()
    new_pairs = pairs ++ [{caller, {module_name, function_name}}]
    # Recursively analyze the callee function body
    case get_function_body(module_name, String.to_atom(function_name), module_map) do
      {:ok, function_body} ->
        extract_call_pairs_recursive(function_body, module_name, module_map, new_pairs)
      :not_found ->
        new_pairs
    end
  end

  defp extract_call_pairs_recursive({:params, _, _}, _caller, _module_map, pairs), do: pairs

  defp extract_call_pairs_recursive({left, right}, caller, module_map, pairs) when is_tuple(left) and is_tuple(right) do
    left_pairs = extract_call_pairs_recursive(left, caller, module_map, pairs)
    extract_call_pairs_recursive(right, caller, module_map, left_pairs)
  end

  defp extract_call_pairs_recursive(ast, _caller, _module_map, pairs) when is_list(ast), do: pairs

  defp extract_call_pairs_recursive(_ast, _caller, _module_map, pairs), do: pairs
end
