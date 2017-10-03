defmodule Ldap.Ecto.Helper do

  alias Ldap.Ecto.Converter

  def load_string(value), do: {:ok, trim_converted(Converter.from_erlang(value))}
  def load_array(array), do: {:ok, Enum.map(array, &Converter.from_erlang/1)}
  def load_date(value) do
    value
    |> to_string
    |> Timex.parse!("{ASN1:GeneralizedTime:Z}")
    |> Timex.Ecto.DateTime.dump
  end

  def dump_in(value), do: {:ok, {:in, Converter.to_erlang(value)}}
  def dump_string(value), do: {:ok, Converter.to_erlang(value)}
  def dump_array(array) when is_list(array), do: {:ok, Converter.to_erlang(array)}
  def dump_date(value) when is_tuple(value) do
    with {:ok, v} <- Timex.Ecto.DateTime.load(value), {:ok, d} <- Timex.format(v, "{ASN1:GeneralizedTime:Z}") do
      {:ok, Converter.to_erlang(d)}
    end
  end

  @doc false
  def construct_filter(%{wheres: wheres}) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&Map.get(&1, :expr))
    {:filter, filter_term}
  end

  @doc false
  def construct_filter(wheres, params) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&(Converter.ecto_lisp_to_eldap_filter(&1, params)))
      |> :eldap.and
    {:filter, filter_term}
  end

  @doc false
  def construct_base(%{from: {from, _}}) do
    {:base, to_char_list(from <> "," <> to_string(Ldap.Ecto.base)) }
  end
  @doc false
  def constuct_base(_), do: {:base, Ldap.Ecto.base}

  @doc false
  def construct_scope(_), do: {:scope, :eldap.wholeSubtree}

  @doc false
  def construct_attributes(%{select: select, sources: sources}) do
    case select.fields do
      [{:&, [], [0]}] ->
        { :attributes,
          sources
          |> ordered_fields
          |> List.flatten
          |> Enum.map(&Converter.to_erlang/1)
        }
      attributes ->
        {
          :attributes,
          attributes
          |> Enum.map(&extract_select/1)
          |> List.flatten
          |> Enum.map(&Converter.to_erlang/1)
        }
    end
  end


  def generate_models(row, process, [{:&, [], [_idx, _columns, _count]}] = fields), do:
    Enum.map(fields, fn field -> process.(field, row, nil) end)
  def generate_models(row, process, [{_,_,fields}]), do:
    Enum.map(fields, fn {field, _} -> process.(field, row, nil) end)
#  def generate_models(row, process, fields) when is_list(fields), do:
#    Enum.map(fields, fn field -> process.(field, row, nil) end)
  def generate_models([field_data | data], process, [{{:., [], [{:&, [], [0]}, _field_name]}, [ecto_type: _type], []} = field | remaining_fields]), do:
    generate_models(data, process, remaining_fields, [process.(field, field_data, nil)])
  def generate_models([field_data | data], process, [field | remaining_fields], mapped_data), do:
    generate_models(data, process, remaining_fields, [process.(field, field_data, nil) | mapped_data])
  def generate_models([], _process, [], mapped_data), do:
    :lists.reverse(mapped_data)


  @spec trim_converted(any) :: any
  def trim_converted(list) when is_list(list), do: hd(list)

  def process_entry({:eldap_entry, dn, attributes}) when is_list(attributes) do
  List.flatten(
    [dn: dn],
    Enum.map(attributes, fn {key, value} ->
      {key |> to_string |> String.to_atom, value}
    end))
  end

  def prune_attrs(attrs, all_fields, [{{:&, [], [0]}, _}] = _selected_fields) do
    for field <- all_fields, do: Keyword.get(attrs, field)
  end
  def prune_attrs(attrs, _all_fields, selected_fields) do
    selected_fields
    |> Enum.map(fn {[{:&, [], _}, field], _} ->
      Keyword.get(attrs, field)
      end)
  end


  def ordered_fields(sources) do
    {_, model} = elem(sources, 0)
    model.__schema__(:fields)
  end

  def count_fields(fields, sources) when is_list(fields), do: fields |> Enum.map(fn field -> count_fields(field, sources) end) |> List.flatten
  def count_fields({{_, _, fields}, _, _}, sources), do: fields |> extract_field_info(sources)
  def count_fields({:&, _, [_idx]} = field, sources), do: extract_field_info(field, sources)
  def count_fields({_, _, fields} , sources), do: fields |> extract_field_info(sources)
  def count_fields({field, _}, sources), do: extract_field_info(field, sources)

  def merge_search_options({filter, []}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
  end
  def merge_search_options({filter, [base: dn]}, full_search_terms) do
    full_search_terms
    |> Keyword.put(:filter, filter)
    |> Keyword.put(:base, dn)
    |> Keyword.put(:scope, :eldap.baseObject)
  end
  def merge_search_options(_, _) do
    raise "Unable to search across multiple base DNs"
  end

  def replace_dn_search_with_objectclass_present(search_options) when is_list(search_options)do
    {filter, dns} =
      search_options
      |> Keyword.get(:filter)
      |> replace_dn_filters
    {filter, dns |> List.flatten |> Enum.uniq}
  end

  def replace_dn_filters([]), do: {[], []}
  def replace_dn_filters([head|tail]) do
    {h, hdns} = replace_dn_filters(head)
    {t, tdns} = replace_dn_filters(tail)
    {[h|t], [hdns|tdns]}
  end
  def replace_dn_filters({:equalityMatch, {:AttributeValueAssertion, 'dn', dn}}) do
    {:eldap.present('objectClass'), {:base, dn}}
  end
  def replace_dn_filters({conjunction, list}) when is_list(list) do
    {l, dns} = replace_dn_filters(list)
    {{conjunction, l}, dns}
  end
  def replace_dn_filters(other), do: {other, []}


  defp extract_select({:&, _, [_, select, _]}), do: select
  defp extract_select({{:., _, [{:&, _, _}, select]}, _, _}), do: select

  defp extract_field_info({:&, _, [idx]} = field, sources) do
    {_source, model} = elem(sources, idx)
    [{field, length(model.__schema__(:fields))}]
  end
  defp extract_field_info(field, _sources) do
    [{field, 0}]
  end

end
