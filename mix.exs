defmodule Ldap.Ecto.Mixfile do
  use Mix.Project

  @description """
    LDAP adapter for Ecto
  """

  def project do
    [
      app: :ldap_ecto,
      version: "0.1.0",
      elixir: "~> 1.5",
      name: "ldap_ecto",
      description: @description,
      package: package(),
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 2.2"},
      {:timex, "~> 3.1"},
      {:timex_ecto, "~> 3.2"}
    ]
  end

  defp package do
    [ maintainers: ["Arthur Vogel"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/vog3l/ldap_ecto"} ]
  end
end
