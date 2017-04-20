defmodule SocksServer.Packet do

  @ipv4Address      1
  @fqdnAddress      3
  @ipv6Address      4



  def parse_hello(<<version::unsigned-size(8),auth_len::unsigned-size(8),methods::binary-size(auth_len)>> <> _rest = data) do
    %{
      version: version,
      auth_type: (for <<method::unsigned-size(8) <- methods>>,do: method)
    }
  end

  def parse_hello(data) do
    :error
  end

  def parse_auth(<<version::unsigned-size(8),ulen::unsigned-size(8),username::binary-size(ulen),plen::unsigned-size(8),password::binary-size(plen)>> <> _rest) do
    {:error,:not_implemented}
  end

  def parse_auth(data) do
    :error
  end

  def parse_request(<<version::unsigned-size(8),method::unsigned-size(8),0::8,@ipv4Address::8,ip::binary-4,port::16>> <> _rest) do
    %{
        version: version,
        method: method,
        type: :ipv4,
        ip: ((for <<i::8 <- ip>>,do: to_string(i)) |> Enum.join(".")),
        port: port
     }
  end

  def parse_request(<<version::unsigned-size(8),method::unsigned-size(8),0::8,@ipv6Address::8,ip::binary-16,port::16>> <> _rest) do
    %{
        version: version,
        method: method,
        type: :ipv6,
        ip: ((for <<i::16 <- ip>>,do: i |> Base.encode16) |> Enum.join(":")),
        port: port
     }
  end

  def parse_request(<<version::unsigned-size(8),method::unsigned-size(8),0::8,@fqdnAddress::8,len::8,addr::binary-size(len),port::16>> <> _rest) do
    %{
        version: version,
        method: method,
        type: :fqdn,
        addr: addr,
        port: port
     }
  end

  def parse_addr(_) do
    :error
  end

  def ip_to_addr({ip1,ip2,ip3,ip4}) do
    <<ip1::8,ip2::8,ip3::8,ip4::8>>
  end
end

