defmodule PipeTrace.TraceTest do
  use ExUnit.Case
  alias PipeTrace.Trace

  describe "from_source_file/2" do
    test "extracts function calls from a simple controller with pipe operators" do
      calls = Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      
      assert calls == ["MyApp.Accounts.:normalize", "MyApp.Accounts.:create_user"]
    end

    test "returns empty list for non-existent function" do
      calls = Trace.from_source_file("test/fixtures/fake_controller.ex", :non_existent)
      
      assert calls == []
    end

    test "handles file with no function definitions" do
      # Create a temporary file with no function definitions
      temp_file = "test/fixtures/empty_file.ex"
      File.write!(temp_file, "defmodule EmptyModule do\nend")
      
      calls = Trace.from_source_file(temp_file, :some_function)
      
      assert calls == []
      
      # Clean up
      File.rm!(temp_file)
    end

    test "handles function with no function calls" do
      # Create a temporary file with a function that has no calls
      temp_file = "test/fixtures/no_calls.ex"
      File.write!(temp_file, """
      defmodule NoCalls do
        def simple_function do
          :ok
        end
      end
      """)
      
      calls = Trace.from_source_file(temp_file, :simple_function)
      
      assert calls == [":ok"]
      
      # Clean up
      File.rm!(temp_file)
    end

    test "handles function with direct module calls" do
      # Create a temporary file with direct module calls
      temp_file = "test/fixtures/direct_calls.ex"
      File.write!(temp_file, """
      defmodule DirectCalls do
        def process_data do
          MyApp.Utils.process()
          MyApp.Utils.validate()
        end
      end
      """)
      
      calls = Trace.from_source_file(temp_file, :process_data)
      
      # The calls are combined into a single string with newlines
      assert length(calls) == 1
      call_string = List.first(calls)
      assert call_string =~ "MyApp.Utils.process()"
      assert call_string =~ "MyApp.Utils.validate()"
      
      # Clean up
      File.rm!(temp_file)
    end

    test "handles complex pipe chains" do
      # Create a temporary file with complex pipe chains
      temp_file = "test/fixtures/complex_pipes.ex"
      File.write!(temp_file, """
      defmodule ComplexPipes do
        def process_user(user_data) do
          user_data
          |> MyApp.Users.validate()
          |> MyApp.Users.normalize()
          |> MyApp.Users.save()
        end
      end
      """)
      
      calls = Trace.from_source_file(temp_file, :process_user)
      
      assert "MyApp.Users.:validate" in calls
      assert "MyApp.Users.:normalize" in calls
      assert "MyApp.Users.:save" in calls
      
      # Clean up
      File.rm!(temp_file)
    end
  end
end 