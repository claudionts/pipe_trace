defmodule PipeTraceTest do
  use ExUnit.Case
  doctest PipeTrace

  describe "generate_diagram/2" do
    test "generates diagram from controller function" do
      File.rm("sequence_diagram.md")
      
      result = PipeTrace.generate_diagram("test/fixtures/fake_controller.ex", :create)
      
      assert result == :ok
      assert File.exists?("sequence_diagram.md")
      
      content = File.read!("sequence_diagram.md")
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Accounts"
      assert content =~ "normalize"
      assert content =~ "create_user"
    end

    test "handles non-existent file gracefully" do
      result = PipeTrace.generate_diagram("non_existent_file.ex", :create)
      
      # Should handle the error gracefully
      assert result == :ok
    end

    test "handles non-existent function gracefully" do
      File.rm("sequence_diagram.md")
      
      result = PipeTrace.generate_diagram("test/fixtures/fake_controller.ex", :non_existent)
      
      assert result == :ok
      assert File.exists?("sequence_diagram.md")
      
      content = File.read!("sequence_diagram.md")
      # Should only have the controller participant
      assert content =~ "participant MyAppWeb.FakeController"
      refute content =~ "->>"
    end

    test "generates diagram with complex controller logic" do
      # Create a temporary file with complex controller logic
      temp_file = "test/fixtures/complex_controller.ex"
      File.write!(temp_file, """
      defmodule ComplexController do
        def process_order(order_data) do
          order_data
          |> MyApp.Orders.validate()
          |> MyApp.Orders.process()
          |> MyApp.Payments.charge()
          |> MyApp.Notifications.send_confirmation()
        end
      end
      """)
      
      File.rm("sequence_diagram.md")
      
      result = PipeTrace.generate_diagram(temp_file, :process_order)
      
      assert result == :ok
      assert File.exists?("sequence_diagram.md")
      
      content = File.read!("sequence_diagram.md")
      assert content =~ "participant ComplexController"
      assert content =~ "participant MyApp.Orders"
      assert content =~ "participant MyApp.Payments"
      assert content =~ "participant MyApp.Notifications"
      assert content =~ "validate"
      assert content =~ "process"
      assert content =~ "charge"
      assert content =~ "send_confirmation"
      
      # Clean up
      File.rm!(temp_file)
    end

    test "generates diagram with different module names" do
      File.rm("sequence_diagram.md")
      
      result = PipeTrace.generate_diagram("test/fixtures/custom_controller.ex", :create)
      
      assert result == :ok
      assert File.exists?("sequence_diagram.md")
      
      content = File.read!("sequence_diagram.md")
      assert content =~ "participant CustomApp.Web.UserController"
      assert content =~ "participant CustomApp.Accounts"
      assert content =~ "validate"
      assert content =~ "create"
    end
  end
end
