defmodule ElixirSocks5.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_socks5,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:logger],
      mod: {ElixirSocks5, []},
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:socket, "~> 0.3"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Yet another socks5 server implementation
    when running alone(iex -S mix), it will listen on port 9898
    import in your project and start it with
    SocksServer.Listener.Sup.start_link(9898)
    Project is published with MIT License
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :elixir_socks5,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["EmiNarcissus"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/eminarcissus/elixir_socks5"}
    ]
  end
end
