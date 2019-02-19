defmodule QRCode.Bits do

  def reverse(bin), do:
    reverse(bin, <<>>)
  defp reverse(<<x :: size(1), bin :: bitstring>>, acc), do:
    reverse(bin, <<x :: size(1), acc :: bitstring>>)
  defp reverse(<<>>, acc), do: acc

  def duplicate(bin, n), do:
    duplicate(bin, n, <<>>)
  defp duplicate(bin, n, acc) when n > 0, do:
    duplicate(bin, n - 1, <<acc :: bitstring, bin :: bitstring>>)
  defp duplicate(_, 0, acc), do: acc

  def append(list), do:
    append(list, <<>>)
  defp append([h|t], acc), do:
    append(t, <<acc :: bitstring, h :: bitstring>>)
  defp append([], acc), do: acc

  def binlist(bin), do:
    binlist(bin, [])
  defp binlist(<<x :: size(1), bin :: bitstring>>, acc), do:
    binlist(bin, [x | acc])
  defp binlist(<<>>, acc), do:
    Enum.reverse(acc)

  def bitstring(bin), do:
    bitstring(bin, <<>>)
  defp bitstring(<<0 :: size(1), bin :: bitstring>>, acc), do:
    bitstring(bin, <<acc :: binary, ?0>>)
  defp bitstring(<<1 :: size(1), bin :: bitstring>>, acc), do:
    bitstring(bin, <<acc :: binary, ?1>>)
  defp bitstring(<<>>, acc), do: acc

  def stringbits(bin), do:
    stringbits(bin, <<>>)
  defp stringbits(<<?0, bin :: binary>>, acc), do:
    stringbits(bin, <<acc :: bitstring, 0 :: size(1)>>)
  defp stringbits(<<?1, bin :: binary>>, acc), do:
    stringbits(bin, <<acc :: bitstring, 1 :: size(1)>>)
  defp stringbits(<<>>, acc), do: acc
end
