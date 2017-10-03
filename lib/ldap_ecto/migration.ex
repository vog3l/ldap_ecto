defmodule Ldap.Ecto.Migration do
  ####
  # Ecto.Adapter.Migration
  ##

  # TYPES

  @type command
    ::  raw :: String.t |
        {:create, Table.t, [table_subcommand]} |
        {:create_if_not_exists, Table.t, [table_subcommand]} |
        {:alter, Table.t, [table_subcommand]} |
        {:drop, Table.t} |
        {:drop_if_exists, Table.t} |
        {:create, Index.t} |
        {:create_if_not_exists, Index.t} |
        {:drop, Index.t} |
        {:drop_if_exists, Index.t}

  @type table_subcommand
    ::  {:add, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
        {:modify, field :: atom, type :: Ecto.Type.t | Reference.t, Keyword.t} |
        {:remove, field :: atom}

  @type ddl_object :: Table.t | Index.t

# CALLBACKS

  @behaviour Ecto.Adapter.Migration

  # Ecto.Adapter.Migration.execute_ddl/3
  @spec execute_ddl(repo :: Ecto.Repo.t, command, options :: Keyword.t)
    ::  :ok |
        no_return

  def execute_ddl(_repo, _command, _options) do

  end

  # Ecto.Adapter.Migration.supports_ddl_transaction?/0
  @spec supports_ddl_transaction?
    ::  boolean

  def supports_ddl_transaction? do

  end
  
end
