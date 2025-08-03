defmodule CustomApp.Accounts do
  def create(params) do
    :ok
  end
  def validate(params) do
    params
    |> CustomApp.AccountChangeset.changeset()
  end
end

