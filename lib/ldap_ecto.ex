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
    base = Keyword.get(opts, :base) |> to_char_list
    {:reply, base, opts}
  end

  def handle_call({:search, search_options}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    search_response = ldap_api(opts).search(handle, search_options)
    ldap_api(opts).close(handle)

    {:reply, search_response, opts}
  end

  def handle_call({:insert, dn, attrs}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    insert_response = ldap_api(opts).add(handle, dn, attrs)
    ldap_api(opts).close(handle)

    {:reply, insert_response, opts}
  end

  def handle_call({:update, dn, modify_operations}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    update_response = ldap_api(opts).modify(handle, dn, modify_operations)
    ldap_api(opts).close(handle)

    {:reply, update_response, opts}
  end

  def handle_call({:delete, dn}, _from, opts) do
    {:ok, handle}   = ldap_connect(opts)
    delete_response = ldap_api(opts).delete(handle, dn)
    ldap_api(opts).close(handle)

    {:reply, delete_response, opts}
  end

  ####
  # Private
  ##

  @spec ldap_api([{atom, any}]) :: :eldap | module
  defp ldap_api(opts) do
    Keyword.get(opts, :ldap_api, :eldap)
  end

  @spec ldap_connect([{atom, any}]) :: {:ok, pid}
  defp ldap_connect(opts) do
    user_dn   = Keyword.get(opts, :user_dn)  |> to_char_list
    password  = Keyword.get(opts, :password) |> to_char_list
    hostname  = Keyword.get(opts, :hostname) |> to_char_list
    port      = Keyword.get(opts, :port, 636)
    use_ssl   = Keyword.get(opts, :ssl, true)

    {:ok, handle} = ldap_api(opts).open([hostname], [{:port, port}, {:ssl, use_ssl}])
    ldap_api(opts).simple_bind(handle, user_dn, password)
    {:ok, handle}
  end

end
