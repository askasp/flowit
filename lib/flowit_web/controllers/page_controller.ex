defmodule FlowitWeb.PageController do
  use FlowitWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
