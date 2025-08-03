defmodule CustomApp.Web.UserController do
  def create(conn, params) do
    params
    |> CustomApp.Accounts.validate()
    |> CustomApp.Accounts.create()
  end
end 
