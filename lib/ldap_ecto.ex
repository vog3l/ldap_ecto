defmodule Ldap.Ecto do
  use GenServer

  def start_link(_repo, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ####
  # Interface
  ##

  @doc false
  def base do
    GenServer.call(__MODULE__, :base)
  end

  @doc false
  def scope do
    GenServer.call(__MODULE__, :scope)
  end

  @doc false
  def search(search_options) do
    GenServer.call(__MODULE__, {:search, search_options})
  end

  @doc false
  def insert(dn, attrs) do
    GenServer.call(__MODULE__, {:insert, dn, attrs})
  end

  @doc false
  def update(dn, modify_operations) do
    GenServer.call(__MODULE__, {:update, dn, modify_operations})
  end

  @doc false
  def delete(dn) do
    GenServer.call(__MODULE__, {:delete, dn})
  end

  ####
  # Callbacks
  ##

  def handle_call(:base, _from, opts) do
    base = Keyword.get(opts, :base) |> to_charlist
    {:reply, base, opts}  # really also the options ???
  end

  def handle_call(:scope, _from, opts) do
    scope = Keyword.get(opts, :scope) |> to_charlist
    {:reply, scope, opts}  # really also the options ???
  end

  def handle_call({:search, search_options}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    search_response = :eldap.search(handle, search_options)
    :eldap.close(handle)

    {:reply, search_response, opts}
  end

  def handle_call({:insert, dn, attrs}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    insert_response = :eldap.add(handle, dn, attrs)
    :eldap.close(handle)

    {:reply, insert_response, opts}
  end

  def handle_call({:update, dn, modify_operations}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    update_response = :eldap.modify(handle, dn, modify_operations)
    :eldap.close(handle)

    {:reply, update_response, opts}
  end

  def handle_call({:delete, dn}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    delete_response = :eldap.delete(handle, dn)
    :eldap.close(handle)

    {:reply, delete_response, opts}
  end

  defp ldap_connect(opts) do
    user_dn   = Keyword.get(opts, :user_dn)  |> to_charlist
    password  = Keyword.get(opts, :password) |> to_charlist
    hostname  = Keyword.get(opts, :hostname) |> to_charlist
    port      = Keyword.get(opts, :port, 636)
    use_ssl   = Keyword.get(opts, :ssl, true)

    {:ok, handle} = :eldap.open([hostname], [{:port, port}, {:ssl, use_ssl}])
    :eldap.simple_bind(handle, user_dn, password)
    {:ok, handle}
  end

  def disconnect() do

  end

end
