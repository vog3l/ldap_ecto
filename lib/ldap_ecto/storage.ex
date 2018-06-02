defmodule Ldap.Ecto.Storage do
  ####
  # Ecto.Adapter.Storage
  ##

  # CALLBACKS

  @behaviour Ecto.Adapter.Storage

  # Ecto.Adapter.Storage.storage_down/1
  @spec storage_down(options :: Keyword.t)
    ::  :ok |
      {:error, :already_down} |
      {:error, term}

  def storage_up(_), do: {:error, :already_up}

  # Ecto.Adapter.Storage.storage_up/1
  @spec storage_up(options :: Keyword.t)
    ::  :ok |
        {:error, :already_up} |
        {:error, term}

  def storage_down(_), do: {:error, :already_down}

end
