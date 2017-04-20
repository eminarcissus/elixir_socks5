defmodule ElixirSocks5 do
  use Application

  def start(_type, _args) do
    SocksServer.Listener.Sup.start_link(9898)
  end
end
