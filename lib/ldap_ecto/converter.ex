defmodule Ldap.Ecto.Converter do

  @spec from_erlang(any) :: any
  def from_erlang(list=[head|_]) when is_list(head), do: Enum.map(list, &from_erlang/1)
  def from_erlang(list) when is_list(list), do: Enum.map(list, &from_erlang/1)
  def from_erlang(string) when is_list(string), do: :binary.list_to_bin(string)
  def from_erlang(num) when is_number(num), do: num
  def from_erlang(other), do: other

  @spec to_erlang(list | String.t | atom | number) :: list | number
  def to_erlang(list) when is_list(list), do: Enum.map(list, &to_erlang/1)
  def to_erlang(string) when is_binary(string), do: :binary.bin_to_list(string)
  def to_erlang(atom) when is_atom(atom), do: atom |> Atom.to_string |> to_erlang
  def to_erlang(num) when is_number(num), do: num


  def options_to_filter([]), do: []
  def options_to_filter(list) when is_list(list) do
    for {attr, value} <- list do
      ecto_lisp_to_eldap_filter({:==, [], [attr, to_erlang(value)]}, [])
    end
  end

  def ecto_lisp_to_eldap_filter({:or, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.or
  end
  def ecto_lisp_to_eldap_filter({:and, _, list_of_subexpressions}, params) do
    list_of_subexpressions
    |> Enum.map(&(ecto_lisp_to_eldap_filter(&1, params)))
    |> :eldap.and
  end
  def ecto_lisp_to_eldap_filter({:not, _, [subexpression]}, params) do
    :eldap.not(ecto_lisp_to_eldap_filter(subexpression, params))
  end
  # {:==, [], [{{:., [], [{:&, [], [0]}, :sn]}, [ecto_type: :string], []}, {:^, [], [0]}]}, ['Weiss', 'jeff.weiss@puppetlabs.com']
  def ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx]}]}, params) do
    ecto_lisp_to_eldap_filter({op, [], [value1, Enum.at(params, idx)]}, params)
  end
  def ecto_lisp_to_eldap_filter({op, [], [value1, {:^, [], [idx,len]}]}, params) do
    ecto_lisp_to_eldap_filter({op, [], [value1, Enum.slice(params, idx, len)]}, params)
  end
  # {:in, [], [{:^, [], [0]}, {{:., [], [{:&, [], [0]}, :uniqueMember]}, [], []}]}, ['uid=manny,ou=users,dc=puppetlabs,dc=com']
  def ecto_lisp_to_eldap_filter({op, [], [{:^, [], [idx]}, value2]}, params) do
    ecto_lisp_to_eldap_filter({op, [], [Enum.at(params, idx), value2]}, params)
  end

  def ecto_lisp_to_eldap_filter({:ilike, _, [value1, "%" <> value2]}, _) do
    like_with_leading_wildcard(value1, value2)
  end
  def ecto_lisp_to_eldap_filter({:ilike, _, [value1, [37|value2]]}, _) do
    like_with_leading_wildcard(value1, from_erlang(value2))
  end
  def ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_list(value2) do
    like_without_leading_wildcard(value1, from_erlang(value2))
  end
  def ecto_lisp_to_eldap_filter({:ilike, _, [value1, value2]}, _) when is_binary(value2) do
    like_without_leading_wildcard(value1, value2)
  end
  def ecto_lisp_to_eldap_filter({:like, a, b}, params) do
    ecto_lisp_to_eldap_filter({:ilike, a, b}, params)
  end
  def ecto_lisp_to_eldap_filter({:==, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value1), translate_value(value2))
  end
  def ecto_lisp_to_eldap_filter({:!=, _, [value1, value2]}, _) do
    :eldap.not(:eldap.equalityMatch(translate_value(value1), translate_value(value2)))
  end
  def ecto_lisp_to_eldap_filter({:>=, _, [value1, value2]}, _) do
    :eldap.greaterOrEqual(translate_value(value1), translate_value(value2))
  end
  def ecto_lisp_to_eldap_filter({:<=, _, [value1, value2]}, _) do
    :eldap.lessOrEqual(translate_value(value1), translate_value(value2))
  end
  def ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) when is_list(value2) do
    for value <- value2 do
      :eldap.equalityMatch(translate_value(value1), translate_value(value))
    end
    |> :eldap.or
  end
  def ecto_lisp_to_eldap_filter({:in, _, [value1, value2]}, _) do
    :eldap.equalityMatch(translate_value(value2), translate_value(value1))
  end
  def ecto_lisp_to_eldap_filter({:is_nil, _, [value]}, _) do
    :eldap.not(:eldap.present(translate_value(value)))
  end


  def translate_value({{:., [], [{:&, [], [0]}, attribute]}, _ecto_type, []}) when is_atom(attribute) do
    translate_value(attribute)
  end
  def translate_value(%Ecto.Query.Tagged{value: value}), do: value
  def translate_value(atom) when is_atom(atom) do
    atom
    |> to_string
    |> to_charlist
  end
  def translate_value(other), do: to_erlang(other)


  defp like_with_leading_wildcard(value1, value2) do
    case String.last(value2) do
      "%" -> :eldap.substrings(translate_value(value1), [{:any, translate_value(String.slice(value2, 0..-2))}])
      _ -> :eldap.substrings(translate_value(value1), [{:final, translate_value(value2)}])
    end
  end
  defp like_without_leading_wildcard(value1, value2) do
    case String.last(value2) do
      "%" -> :eldap.substrings(translate_value(value1), [{:initial, translate_value(String.slice(value2, 0..-2))}])
      _ -> :eldap.substrings(translate_value(value1), [{:any, translate_value(value2)}])
    end
  end

end
