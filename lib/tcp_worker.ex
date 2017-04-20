defmodule SocksServer.WorkerSup do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(SocksServer.Worker, []),
    ]

    # supervise/2 is imported from Supervisor.Spec
    supervise(children, strategy: :simple_one_for_one,restart: :temporary)
  end

  def start_child(pid,args) do
    Supervisor.start_child(pid,args)
  end
end
defmodule SocksServer.Worker do
  defstruct [:socket,:proxy]
  use GenServer
  alias SocksServer.Server

  def start(socket) do
    GenServer.start(__MODULE__,[socket],[name: __MODULE__])
  end

  def start_link(socket) do
    GenServer.start_link(__MODULE__,[socket],[])
  end

  def init([socket]) do
    {:ok,%__MODULE__{socket: socket},0}
  end

  def handle_call({_proxy_state,data},from,%__MODULE__{socket: socket} = state) do
    #CALLBACK function when proxy received message,we need to send out back to receiver
    socket |> Socket.Stream.send(data)
    {:reply,:ok,state}
  end

  def handle_call({:reply,data},from,%__MODULE__{socket: socket} = state) do
    #CALLBACK function when proxy received message,we need to send out back to receiver
    socket |> Socket.Stream.send(data)
    {:reply,:ok,state}
  end

  def handle_info(:timeout,%__MODULE__{socket: socket} = state) do
    {:ok,proxy} = Server.start_link(__MODULE__)
    socket |> Socket.active(:once)
    {:noreply,%{state|proxy: proxy}}
  end

  def handle_info({:tcp,_,data},%__MODULE__{socket: socket,proxy: proxy} = state) do
    send(proxy,{:data,data})
    socket |> Socket.active(:once)
    {:noreply,state}
  end

  def handle_info({:tcp_closed,_socket},%__MODULE__{} = state) do
    {:stop,:normal,state}
  end

  def handle_info({:tcp_error,_socket,reason},%__MODULE__{} = state) do
    {:stop,:tcp_error,state}
  end

  def terminate(reason,%__MODULE__{socket: socket} = state) do
    socket |> Socket.close()
    :ok
  end
end
