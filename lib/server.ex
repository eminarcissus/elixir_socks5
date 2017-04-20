defmodule SocksServer.Server do
  use GenServer
  alias SocksServer.Packet

  @connectCommand   1
  @bindCommand      2
  @associateCommand 3


  @no_auth 0
  @gssapi_auth 1
  @username_auth 2
  defstruct [:method,:target,:sock,:caller,:delegate,auth_method: @no_auth,data: <<>>,state: :init,user_info: :nil]


  
  def resolve(name) do
    case :inet_res.gethostbyname(name |> String.to_charlist) do
      {:error,_} -> :error
      {:ok,{:hostent,_,_,:inet,ver,ips}} -> {:ok,ips}
    end
  end

  def start_link(delegate) do
    GenServer.start_link(__MODULE__,[delegate,self],[])
  end

  def handle_request(%__MODULE__{method: @connectCommand,target: %{ip: ip,port: port,type: type} = target}) do
    hostname = if type == :fqdn,do: target[:addr],else: ip
    case Socket.connect( "tcp://#{hostname}:#{port}") do
      {:ok,sock} -> sock
      {:ok,{ip,port}} = :inet.sockname(sock)
      {:ok,{ip,port},sock}
      {:error,e} -> {:error,:unable_to_connect}
    end
  end

  def handle_request(%__MODULE__{method: :bind}) do
    {:error,:not_supported}
  end

  def handle_request(%__MODULE__{method: :associate}) do
    {:error,:not_supported}
  end

  def init([delegate,caller]) do
    {:ok,%__MODULE__{delegate: delegate,caller: caller}}
  end

  def send_message(caller,state,msg) do
    GenServer.call(caller,{state,msg})
  end

  def choose_method(methods) do
    {:ok,{:request,@no_auth,<<5::8,0::8>>}}
  end

  def handle_info({:data,new_data},%__MODULE__{state: :init,data: data,caller: caller} = state) do
    handle_data = data <> new_data
    if handle_data |> byte_size >= 2 do
      case Packet.parse_hello(handle_data) do
        %{ version: v } when v != 5 -> {:stop,:incorrect_version,state}
        %{ auth_type: auth_types} -> 
              case choose_method(auth_types) do
                {:ok, {new_state,auth_method,msg}} -> 
                  #ok parse
                  send_message(caller,new_state,msg)
                  {:noreply,%{state| auth_method: auth_method,state: new_state,data: <<>>}}
                {:error,_} -> 
                  {:stop,:no_auth_method,state}
              end

        :error -> 
          #TODO what about timeout?
          #error parse method,maybe not finished transfer
          {:noreply,%{state|data: handle_data}}
      end
    else
        #packet size < 2,wait more
        {:noreply,%{state|data: handle_data}}
    end
  end

  def handle_info({:data,new_data},%__MODULE__{state: :hello,auth_method: @username_auth,data: data,caller: caller} = state) do
    handle_data = data <> new_data
    case Packet.parse_auth(handle_data) do
      {:error,:not_implemented} -> {:stop,:auth_error,state}
      %{ version: v } when v != 5 -> {:stop,:incorrect_version,state}
      %{user_info: user_info} ->  send_message(caller,:request,<<5::8,0::8>>)
                                  {:noreply,%{state|state: :request,data: <<>>}}
      :error -> 
      #TODO timeout here?
      {:noreply,%{state|data: handle_data}}
    end
  end

  def handle_info({:data,new_data},%__MODULE__{state: :request,data: data,caller: caller} = state) do
    handle_data = data <> new_data
    case Packet.parse_request(handle_data) do
      %{ version: v } when v != 5 -> {:stop,:incorrect_version,state}
      %{ method: m } when m != @connectCommand -> {:stop,:not_supported,state}
      %{ method: @connectCommand,ip: ip,port: port,type: type} = result  ->  
      state = %{state|method: @connectCommand,target: %{ip: ip,port: port,type: type,addr: result[:addr]}}
      case handle_request(state) do
        {:ok, {ip,port},sock} -> 
                  sock |> Socket.TCP.process(self)
                  sock |> Socket.active(:once)
                  send_message(caller,:ready,<<5::8,0::8,0::8,1::8>> <> Packet.ip_to_addr(ip) <> <<port::unsigned-16>>)
                  {:noreply,%{state|state: :ready,data: <<>>,sock: sock}}
        {:error,reason} -> {:stop,reason,state}
      end
    end
  end

  def handle_info({:data,new_data},%__MODULE__{state: :ready,sock: socket} = state) do
    socket |> Socket.Stream.send!(new_data)
    {:noreply,state}
  end

  def handle_info({:tcp,_socket,data},%__MODULE__{caller: caller,delegate: delegate,sock: sock} = state) do
    #TODO delegate must implement handle_message function to blocking finish this message before we can receive more
    :ok = GenServer.call(caller,{:reply,data})
    #send_message(caller,:proxy,data)
    sock |> Socket.active(:once)
    {:noreply,state}
  end

  def handle_info({:tcp_passive,_socket},%__MODULE__{sock: sock} = state) do
    sock |> Socket.active(:once)
  end

  def handle_info({:tcp_closed,_socket},%__MODULE__{caller: caller} = state) do
    {:stop,:normal,state}
  end

  def handle_info({:tcp_error,_socket,reason},%__MODULE__{caller: caller} = state) do
    {:stop,:tcp_error,state}
  end

  def terminate(reason,%__MODULE__{sock: socket} = state) do
    socket |> Socket.close()
    :ok
  end

end
