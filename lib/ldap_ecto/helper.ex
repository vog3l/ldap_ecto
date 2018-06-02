defmodule Ldap.Ecto.Helper do

  alias Ldap.Ecto.Converter

  def load_string(value), do: {:ok, trim_converted(Converter.from_erlang(value))}
#  def load_integer(value), do: {:ok, trim_converted(Converter.from_erlang(value))}
  def load_array(array), do: {:ok, Enum.map(array, fn x -> trim_converted(Converter.from_erlang(x)) end)}
  def load_date(value) do
    value
    |> to_string
    |> Timex.parse!("{ASN1:GeneralizedTime:Z}")
    |> Timex.Ecto.DateTime.dump
  end

  def dump_in(value), do: {:ok, {:in, Converter.to_erlang(value)}}
#  def dump_integer(value), do: {:ok, Converter.to_erlang(value)}
  def dump_string(value), do: {:ok, Converter.to_erlang(value)}
  def dump_array(value) when is_list(value) do
     Enum.each(value, fn(x) ->
       {:ok, Converter.to_erlang(x)}
     end)
  end
  def dump_date(value) when is_tuple(value) do
    with {:ok, v} <- Timex.Ecto.DateTime.load(value), {:ok, d} <- Timex.format(v, "{ASN1:GeneralizedTime:Z}") do
      {:ok, Converter.to_erlang(d)}
    end
  end

  def process_entry({:eldap_entry, dn, attrs}) when is_list(attrs) do
  List.flatten(
    [dn: dn],
    Enum.map(attrs, fn {key, value} ->
      {key |> to_string |> String.to_atom, value}
    end))
  end

  def prune_attrs(attrs, all_fields) do
    for field <- all_fields, do: Keyword.get(attrs, field)
  end

  def count_fields(fields) when is_list(fields), do: fields |> Enum.map(fn field -> count_fields(field) end)
  def count_fields({_, _, fields}), do: Enum.count(fields)

  # do i really need it ???
  @spec trim_converted(any) :: any
  def trim_converted(list) when is_list(list), do: hd(list)
  def trim_converted(list), do: list

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


  def generate_modify_operation(attr, nil, _) do
    :eldap.mod_replace(Converter.to_erlang(attr), [])
  end
  def generate_modify_operation(attr, [], {:array, _}) do
    :eldap.mod_replace(Converter.to_erlang(attr), [])
  end
  def generate_modify_operation(attr, value, {:array, _}) do
    :eldap.mod_replace(Converter.to_erlang(attr), value)
  end
  def generate_modify_operation(attr, value, _) do
    :eldap.mod_replace(Converter.to_erlang(attr), [value])
  end

end
