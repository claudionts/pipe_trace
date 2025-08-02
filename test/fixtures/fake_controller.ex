defmodule MyAppWeb.FakeController do
  def create(conn, params) do
    params
    |> MyApp.Accounts.normalize()
    |> MyApp.Accounts.create_user()
  end
end
