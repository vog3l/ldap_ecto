defmodule Ldap.Ecto.Constructer do

  alias Ldap.Ecto.Converter

  @doc false
  def get_dn(model, fields) do
    primary_key = Enum.at(model.__schema__(:primary_key),0)
    primary_value = Keyword.get(fields, primary_key)
    schema = model.__schema__(:source)

    to_charlist(primary_key) ++ '=' ++ to_charlist(primary_value) ++ ',' ++ to_charlist(schema) ++ ',' ++ to_charlist(Ldap.Ecto.base)
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
    {:base, to_charlist(from <> "," <> to_string(Ldap.Ecto.base)) }
  end

  @doc false
  def get_scope(_) do
    case to_string(Ldap.Ecto.scope) do
      "baseObject" -> {:scope, :eldap.baseObject}
      "singleLevel" -> {:scope, :eldap.singleLevel}
      "wholeSubtree" -> {:scope, :eldap.wholeSubtree}
      _ -> {:scope, :eldap.singleLevel}
    end
  end

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
