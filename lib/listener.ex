defmodule SocksServer.Listener do
  defmodule Sup do
    use Supervisor
    def start_link(port) do
      Supervisor.start_link(__MODULE__, [port])
    end

    def init([port]) do
      children = [
        worker(SocksServer.Listener, [port])
      ]

      # supervise/2 is imported from Supervisor.Spec
      supervise(children, strategy: :one_for_one)
    end
  end

  def start_link(port) do
    {:ok,spawn_link(__MODULE__,:listen,[port])}
  end

  def listen(port) do
    socket = Socket.listen! "tcp://*:#{port}"
    {:ok,sup} = SocksServer.WorkerSup.start_link
    listen(socket,sup)
  end

  def listen(socket,sup) do
    {:ok,sock} = socket |> Socket.accept()
    {:ok,pid} = SocksServer.WorkerSup.start_child(sup,[sock])
    sock |> Socket.process!(pid)
    listen(socket,sup)
  end

end
