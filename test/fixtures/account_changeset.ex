defmodule CustomApp.AccountChangeset do
  def changeset(params) do
    params
    |> CustomApp.Validators.validate_email()
    |> CustomApp.Validators.validate_password()
  end
end

