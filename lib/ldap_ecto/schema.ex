defmodule Ldap.Ecto.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:cn, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
