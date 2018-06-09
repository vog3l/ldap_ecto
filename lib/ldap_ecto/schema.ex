defmodule Ldap.Ecto.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:dn, :string, autogenerate: false}
      @foreign_key_type :string
    end
  end
end
