defmodule Ldap.Ecto.Constructer do

  alias Ldap.Ecto.Converter
  
  @doc false
  def get_dn(model) do
    primary_keys = model.__schema__(:primary_key)
    fields = model.__schema__(:fields)
    schema = model.__schema__(:source)

    primary =
      Enum.filter(fields, fn {k,v} ->
         Enum.each(primary_keys, fn x ->
           x == k
         end)
      end)

    {key, value} = Enum.at(primary, 0)

    to_string(key) <> "=" <> to_string(value) <> "," <> to_string(schema) <> "," <> to_string(Ldap.Ecto.base)
  end

  @doc false
  def get_filter(%{wheres: wheres}) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&Map.get(&1, :expr))
    {:filter, filter_term}
  end

  @doc false
  def get_filter(wheres, params) when is_list(wheres) do
    filter_term =
      wheres
      |> Enum.map(&(Converter.ecto_lisp_to_eldap_filter(&1, params)))
      |> :eldap.and
    {:filter, filter_term}
  end

  @doc false
  def get_base(%{from: {from, _}}) do
    {:base, to_char_list(from <> "," <> to_string(Ldap.Ecto.base)) }
  end
  @doc false
#  def get_base(_), do: {:base, Ldap.Ecto.base}

  @doc false
  def get_scope(_), do: {:scope, :eldap.wholeSubtree}

  @doc false
  def get_attrs(%{select: select}) do
    attrs =
      Enum.map(select.fields, fn(field) ->
        field
        |> extract_attr
        |> Converter.to_erlang
      end)

    { :attributes, ['dn'] ++ attrs }
  end

  defp extract_attr({{_, _, [{:&, _, _}, attr]}, _, _}), do: attr
end
