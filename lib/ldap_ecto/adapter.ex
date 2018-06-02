defmodule Ldap.Ecto.Adapter do
  ####
  # Ecto.Adapter
  ##

  # TYPES

  # @type t :: Ecto.Adapter.t
  @type t :: Ecto.Adapter.Custom

  @type query_meta
    :: %{
      prefix: binary | nil,
      sources: tuple,
      preloads: term,
      select: map
    }

  @type schema_meta
    :: %{
      source: source,
      schema: atom,
      context: term,
      autogenerate_id: {atom, :id | :binary_id}
    }

  @type source
    :: {prefix :: binary | nil, table :: binary}

  @type fields
    :: Keyword.t

  @type filters
    :: Keyword.t

  @type constraints
    :: Keyword.t

  @type returning
    :: [atom]

  @type prepared
    :: term

  @type cached
    :: term

  @type process
    :: (field :: Macro.t, value :: term, context :: term -> term)

  @type on_conflict
    :: {:raise, list(), []} |
       {:nothing, list(), [atom]} |
       {Ecto.Query.t, list(), [atom]}

#  @type autogenerate_id
#    :: {field :: atom, type :: :id | :binary_id, value :: term} | nil

  @typep repo :: Ecto.Repo.t

  @typep options :: Keyword.t


  # CALLBACKS

  @behaviour Ecto.Adapter

  alias Ldap.Ecto
  alias Ldap.Ecto.{Constructer, Converter, Helper}

  # Ecto.Adapter.__before_compile__/1
  # @spec __before_compile__(term, env :: Macro.Env.t) :: Macro.t # <- extra term in docs?
  # @spec __before_compile__(env :: Macro.Env.t) :: Macro.t
  @impl true
  defmacro __before_compile__(env) do
  #  schema_meta =
    module = env.module
    config = Module.get_attribute(module, :schme_meta)
  #  quote do
      IO.inspect config
  #  end
  end


  # Ecto.Adapter.autogenerate/1
  @spec autogenerate(field_type :: :id | :binary_id | :embed_id)
    ::  term |
        nil |
        no_return

  @impl true
  def autogenerate(:id), do: nil
  def autogenerate(:embed_id),  do: Ecto.UUID.generate()
  def autogenerate(:binary_id), do: Ecto.UUID.bingenerate()


  # Ecto.Adapter.child_spec/2
  @spec child_spec(repo, options)
    :: :supervisor.child_spec
  @impl true
  def child_spec(repo, options) do
    Supervisor.Spec.worker(Ldap.Ecto, [repo, options], name: Ldap.Ecto)
  end


  # Ecto.Adapter.ensure_all_started/2
  @spec ensure_all_started(repo, type :: :application.restart_type)
    ::  {:ok, [atom]} |
        {:error, atom}
  @impl true
  def ensure_all_started(_repo, _restart_type) do
    {:ok, []}
  end


  # Ecto.Adapter.prepare/2
  @spec prepare(atom :: :all | :update_all | :delete_all, query :: Ecto.Query.t)
    ::  {:cache, prepared} |
        {:nocache, prepared}
  @impl true
  def prepare(:all, query) do
    prepared_query =
      [
        Constructer.get_filter(query),
        Constructer.get_base(query),
        Constructer.get_scope(query),
        Constructer.get_attrs(query),
      ]
      |> Enum.filter(&(&1))

    {:nocache, prepared_query}
  end
  def prepare(:update_all, query), do: raise "Update all is currently unsupported"
  def prepare(:delete_all, query), do: raise "Delete all is currently unsupported"


  # Ecto.Adapter.execute/6
  @spec execute(repo, query_meta, query, params :: list, process | nil, options)
    :: result
    when
      result: {integer, [[term]] | nil} | no_return,
      query:
        {:nocache, prepared} |
        {:cached, (prepared -> :ok), cached} |
        {:cache, (cached -> :ok), prepared}
  @impl true
  def execute(_repo, query_meta, {:nocache, prepared_query}, params, process, options) do
    filter =
      if options == [] do
        if Keyword.get(prepared_query, :filter) == [] do
          "*"
        else
          {:filter, filter} = Constructer.get_filter(Keyword.get(prepared_query, :filter), params)
          filter
        end
      else
        :eldap.and(Converter.options_to_filter(options))
      end

    search_response =
      prepared_query
      |> Keyword.put(:filter, filter)
      |> Helper.replace_dn_search_with_objectclass_present
      |> Helper.merge_search_options(prepared_query)
      |> Ldap.Ecto.search

    {:ok, {:eldap_search_result, results, []}} = search_response

#    fields = Helper.ordered_fields(query_meta.sources)

    # this fields are ordered
    {_, model} = elem(query_meta.sources, 0)
    fields = model.__schema__(:fields)

    count = Helper.count_fields(query_meta.select.preprocess)

    result_set =
      for entry <- results do
        entry
        |> Helper.process_entry
        |> Helper.prune_attrs(fields)
        |> process.()
      end

    {count, result_set}
  end


  # Ecto.Adapter.insert/6
  @spec insert(repo, schema_meta, fields, on_conflict, returning, options)
    ::  {:ok, fields} |
        {:invalid, constraints} |
        no_return
  @impl true
  def insert(_repo, schema_meta, fields, _on_conflict, _returning, _options) do
    dn = Constructer.get_dn(schema_meta.schema, fields)

    prepared_fields =
      Enum.flat_map fields, fn({k, v}) ->
        case v do
          :objectClass  -> Enum.each v, fn(x) -> {to_string(k),to_string(v)} end
          _ -> {to_string(k),to_string(v)}
        end
      end


    case Ldap.Ecto.insert(dn, prepared_fields) do
      :ok ->
        {:ok, []}
      {:error, reason} ->
        {:invalid, [reason]}
    end
  end


  # Ecto.Adapter.insert_all/7
  @spec insert_all(repo, schema_meta, header :: [atom], [fields], on_conflict, returning, options)
    ::  {integer, [[term]] | nil} |
        no_return

  @impl true
  def insert_all(_repo, _schema_meta, _header, _rows, _on_conflict, _returning, _options) do

  end


  # Ecto.Adapter.update/6
  @spec update(repo, schema_meta, fields, filters, returning, options)
    ::  {:ok, fields} |
        {:invalid, constraints} |
        {:error, :stale} |
        no_return

  @impl true
  def update(_repo, schema_meta, fields, filters, _returning, _options) do
    dn = Constructer.get_dn(schema_meta.schema, filters)

    modify_operations =
      for {attribute, value} <- fields do
        type = schema_meta.schema.__schema__(:type, attribute)
        Helper.generate_modify_operation(attribute, value, type)
      end

    case Ldap.Ecto.update(dn, modify_operations) do
      :ok ->
        {:ok, []}
      {:error, reason} ->
        {:invalid, [reason]}
    end
  end


  # Ecto.Adapter.delete/4
  @spec delete(repo, schema_meta, filters, options)
    ::  {:ok, fields} |
        {:invalid, constraints} |
        {:error, :stale} |
        no_return

  @impl true
  def delete(_repo, schema_meta, filters, _options) do
    dn = Constructer.get_dn(schema_meta.schema, filters)

    case Ldap.Ecto.delete(dn) do
      :ok ->
        {:ok, []}
      {:error, reason} ->
        {:invalid, [reason]}
    end
  end


  # Ecto.Adapter.loaders/2
  @spec loaders(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t)
    :: [(term -> {:ok, term} | :error) | Ecto.Type.t]

  @impl true
  def loaders(:id, type), do: [type]
  def loaders(:string, _type), do: [&Helper.load_string/1]
  def loaders(:binary, _type), do: [&Helper.load_string/1]
  def loaders(:datetime, _type), do: [&Helper.load_date/1]
  def loaders(Ecto.DateTime, _type), do: [&Helper.load_date/1]
  def loaders({:array, :string}, _type), do: [&Helper.load_array/1]
  def loaders(_primitive, nil), do: [nil]
  def loaders(_primitive, type), do: [type]
#  def loaders(:integer, _type), do: [&Helper.load_integer/1]

  # Ecto.Adapter.dumpers/2
  @spec dumpers(primitive_type :: Ecto.Type.primitive, ecto_type :: Ecto.Type.t)
    :: [(term -> {:ok, term} | :error) | Ecto.Type.t]

  @impl true
  def dumpers(_, nil), do: {:ok, nil}
  def dumpers({:in, _type}, {:in, _}), do: [&Helper.dump_in/1]
  def dumpers(:string, _type), do: [&Helper.dump_string/1]
  def dumpers({:array, :string}, _type), do: [&Helper.dump_array/1]
  def dumpers(:datetime, _type), do: [&Helper.dump_date/1]
  def dumpers(Ecto.DateTime, _type), do: [&Helper.dump_date/1]
  def dumpers(_primitive, type), do: [type]
#  def dumpers(:integer, _type), do: [&Helper.dump_integer/1]

end
