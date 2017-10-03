defmodule Ldap.Ecto.Transaction do
  ####
  # Ecto.Adapter.Transaction
  ##

  # CALLBACKS

  @behaviour Ecto.Adapter.Transaction

  # Ecto.Adapter.Transaction.in_transaction?/1
  @spec in_transaction?(repo :: Ecto.Repo.t)
    ::  boolean

  def in_transaction?(_repo) do

  end

  # Ecto.Adapter.Transaction.rollback/2
  @spec rollback(repo :: Ecto.Repo.t, value :: any)
    ::  no_return

  def rollback(_repo, _value) do

  end

  # Ecto.Adapter.Transaction.transaction/3
  @spec transaction(repo :: Ecto.Repo.t, options :: Keyword.t, function :: (... -> any))
    ::  {:ok, any} |
        {:error, any}

  def transaction(_repo, _options, _function) do

  end
  
end
