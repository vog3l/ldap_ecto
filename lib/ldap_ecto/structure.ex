defmodule Ldap.Ecto.Structure do
  ####
  # Ecto.Adapter.Structure
  ##

  # CALLBACKS

  @behaviour Ecto.Adapter.Structure

  # Ecto.Adapter.Structure.structure_dump/2
  @spec structure_dump(default :: String.t, config :: Keyword.t)
    ::  {:ok, String.t} |
        {:error, term}

  def structure_dump(_default, _config) do

  end

  # Ecto.Adapter.Structure.structure_load/2
  @spec structure_load(default :: String.t, config :: Keyword.t)
    ::  {:ok, String.t} |
        {:error, term}

  def structure_load(_default, _config) do

  end

end
