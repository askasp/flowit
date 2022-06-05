defmodule FlowitWeb.UserAuth.SessionController do
  use FlowitWeb, :controller

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end


  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> <%= inspect schema.alias %>Auth.log_out_user()
  end
end
