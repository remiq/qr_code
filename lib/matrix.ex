defmodule QRCode.Matrix do
  alias QRCode.Params
  alias QRCode.Bits
  require Bitwise

  @finder_bits <<6240274796270654599595212063015969838585429452563217548030 :: size(192)>>

  def dimension(version) when version > 0 and version < 41, do: 17 + (version * 4)

  def template(%Params{version: version, align_coords: align_coords}), do:
    template(version, align_coords)

  def embed_data(%Params{version: version, align_coords: align_coords, remainder: remainder}, codewords) do
    flipped_template = version
      |> template(align_coords)
      #|> IO.inspect
      |> flip()
      #|> IO.inspect
    flipped_matrix = embed_data(flipped_template, <<codewords :: binary, 0 :: size(remainder)>>, [])
    flip(flipped_matrix)
  end

  def overlay_static(%Params{version: version, align_coords: align_coords}, matrix) do
    f = finder_bits()
    t = timing_bits(version, align_coords)
    a = alignment_bits(align_coords)
    overlay_static(matrix, f, t, a, [])
  end

  def finalize(dim, fmt, vsn, qz, matrix) do
    m = format_bits(fmt)
    v = version_bits(vsn)
    final_matrix = overlay_format(matrix, m, v, [])
    q_bit_length = (dim + qz * 2) * qz
    q = << 0 :: size(q_bit_length) >>
    bin = encode_bits(final_matrix, qz, q)
    << bin :: bitstring, q :: bitstring >>
  end

  ###

  defp template(version, ac) do
    dim = dimension(version)
    template(1, dim, ac, [])
  end
  defp template(y, max, ac, acc) when y <= max do
    row = template_row(1, y, max, ac, [])
    template(y + 1, max, ac, [row | acc])
  end
  defp template(_, _, _, acc), do: Enum.reverse(acc)

  defp template_row(x, y, max, ac, acc) when x <= max do
    ref = template_ref(x, y, max, ac)
    template_row(x + 1, y, max, ac, [ref | acc])
  end
  defp template_row(_, _, _, _, acc), do: Enum.reverse(acc)

  defp template_ref(x, y, _max, _ac) when (x <= 8 and y <= 8), do: :f
  defp template_ref(x, y, max, _ac) when (x <= 8 and y > max - 8), do: :f
  defp template_ref(x, y, max, _ac) when (x > max - 8 and y <= 8), do: :f


  defp template_ref(x, y, max, _ac) when (x == 9 and y != 7 and (y <= 9 or max - y <= 7)), do: :m
  defp template_ref(x, y, max, _ac) when (y == 9 and x != 7 and (x <= 9 or max - x <= 7)), do: :m

  defp template_ref(x, y, max, _ac) when max >= 45 and (x < 7 and max - y <= 10), do: :v
  defp template_ref(x, y, max, _ac) when max >= 45 and (y < 7 and max - x <= 10), do: :v
  defp template_ref(x, y, max, ac) do
    case is_alignment_bit(x, y, ac) do
      true -> :a
      false -> template_ref0(x, y, max)
    end
  end

  defp template_ref0(x, y, _) when x == 7 or y == 7, do: :t
  defp template_ref0(_, _, _), do: :d
  #defp template_ref0(x, y, max), do: {x, y, max}

  defp is_alignment_bit(x, y, [{xa, ya} | _]) when (x >= xa - 2 and x <= xa + 2 and y >= ya - 2 and y <= ya + 2), do: true
  defp is_alignment_bit(x, y, [_ | t]), do: is_alignment_bit(x, y, t)
  defp is_alignment_bit(_, _, []), do: false

  defp embed_data([ha, hb, h, hc, hd | t], codewords, acc) when length(t) == 4 do
    {ha, hb, codewords} = embed_data(ha, hb, codewords, [], [])
    {hc, hd, codewords} = embed_data_reversed(hc, hd, codewords)
    embed_data(t, codewords, [hd, hc, h, hb, ha | acc])
  end
  defp embed_data([ha, hb, hc, hd | t], codewords, acc) do
    {ha, hb, codewords} = embed_data(ha, hb, codewords, [], [])
    {hc, hd, codewords} = embed_data_reversed(hc, hd, codewords)
    embed_data(t, codewords, [hd, hc, hb, ha | acc])
  end
  defp embed_data([], <<>>, acc), do: Enum.reverse(acc)

  defp embed_data([:d | t0], [:d | t1], <<a :: size(1), b :: size(1), codewords :: bitstring>>, stream_a, stream_b), do:
    embed_data(t0, t1, codewords, [a | stream_a], [b | stream_b])
  defp embed_data([:d | t0], [b | t1], <<a :: size(1), codewords :: bitstring >>, stream_a, stream_b), do:
    embed_data(t0, t1, codewords, [a | stream_a], [b | stream_b])
  defp embed_data([a | t0], [:d | t1], <<b :: size(1), codewords :: bitstring>>, stream_a, stream_b), do:
    embed_data(t0, t1, codewords, [a | stream_a], [b | stream_b])
  defp embed_data([a | t0], [b | t1], codewords, stream_a, stream_b), do:
    embed_data(t0, t1, codewords, [a | stream_a], [b | stream_b])
  defp embed_data([], [], codewords, stream_a, stream_b), do:
    {Enum.reverse(stream_a), Enum.reverse(stream_b), codewords}

  defp embed_data_reversed(a, b, codewords) do
    {a, b, codewords} = embed_data(Enum.reverse(a), Enum.reverse(b), codewords, [], [])
    {Enum.reverse(a), Enum.reverse(b), codewords}
  end


  defp overlay_static([h | l], f, t, a, acc) do
    {f, t, a, row} = overlay0(h, f, t, a, [])
    #IO.inspect({h})
    overlay_static(l, f, t, a, [row | acc])
  end
  defp overlay_static([], <<>>, <<>>, <<>>, acc), do: Enum.reverse(acc)

  defp overlay0([:f | l], <<f0 :: size(1), f :: bitstring>>, t, a, acc), do:
    overlay0(l, f, t, a, [f0 | acc])
  defp overlay0([:t | l], f, <<t0 :: size(1), t :: bitstring>>, a, acc), do:
    overlay0(l, f, t, a, [t0 | acc])
  defp overlay0([:a | l], f, t, <<a0 :: size(1), a :: bitstring>>, acc), do:
    overlay0(l, f, t, a, [a0 | acc])
  defp overlay0([h | l], f, t, a, acc), do:
    overlay0(l, f, t, a, [h | acc])
  defp overlay0([], f, t, a, acc), do:
    {f, t, a, Enum.reverse(acc)}

  defp encode_bits([h | t], qz, acc) do
    acc = encode_bits0(h, <<acc :: bitstring, 0 :: size(qz)>>)
    encode_bits(t, qz, <<acc :: bitstring, 0 :: size(qz)>>)
  end
  defp encode_bits([], _, acc), do: acc

  defp encode_bits0([h | t], acc) when is_integer(h), do:
    encode_bits0(t, <<acc :: bitstring, h :: size(1)>>)
  defp encode_bits0([], acc), do: acc

  defp overlay_format([h | l], m, v, acc) do
    {m, v, row} = overlay1(h, m, v, [])
    overlay_format(l, m, v, [row | acc])
  end
  defp overlay_format([], <<>>, <<>>, acc), do: Enum.reverse(acc)

  defp overlay1([:m | l], <<m0 :: size(1), m :: bitstring>>, v, acc), do:
    overlay1(l, m, v, [m0 | acc])
  defp overlay1([:v | l], m, <<v0 :: size(1), v :: bitstring>>, acc), do:
    overlay1(l, m, v, [v0 | acc])
  defp overlay1([h | l], m, v, acc), do:
    overlay1(l, m, v, [h | acc])
  defp overlay1([], m, v, acc), do:
    {m, v, Enum.reverse(acc)}

  defp flip(l), do:
    flip(l, [])
  defp flip([[] | _t], acc), do:
    acc
    |> Enum.map(fn l -> Enum.reverse(l) end)
  defp flip(l, acc) do
    heads = Enum.map(l, fn [h | _] -> h end)
    tails = Enum.map(l, fn [_ | t] -> t end)
    flip(tails, [heads | acc])
  end

  defp finder_bits, do: @finder_bits

  defp alignment_bits(ac) do
    repeats = composite_ac(ac, [])
    alignment_bits(repeats, <<>>)
  end
  defp alignment_bits([h | t], acc) do
    bits0 = Bits.duplicate(<<31 :: size(5)>>, h)
    bits1 = Bits.duplicate(<<17 :: size(5)>>, h)
    bits2 = Bits.duplicate(<<21 :: size(5)>>, h)
    bits = Bits.append([bits1, bits2, bits1, bits0])
    alignment_bits(t, <<acc :: bitstring, bits :: bitstring>>)
  end
  defp alignment_bits([], acc), do: acc

  defp composite_ac([{_, row} | t], acc) do
    l = t
      |> Enum.filter(fn {_x, y} -> y == row end)
    n = 1 + length(l)
    t = t
      |> Enum.filter(fn {_x, y} -> y != row end)
    composite_ac(t, [n | acc])
  end
  defp composite_ac([], acc), do: Enum.reverse(acc)

  defp timing_bits(version, ac) do
    length = dimension(version) - 16
    th = timing_bits(1, length, (for {x, 7} <- ac, do: x - 8 - 2), <<>>)
    tv = timing_bits(1, length, (for {7, y} <- ac, do: y - 8 - 2), <<>>)
    <<th :: bitstring, tv :: bitstring>>
  end
  defp timing_bits(n, max, a, acc) when n <= max do
    case :lists.member(n, a) do
      true -> timing_bits(n + 5, max, a, acc)
      false ->
        bit = Bitwise.band(n, 1)
        timing_bits(n + 1, max, a, << acc :: bitstring, bit :: size(1)>>)
    end
  end
  defp timing_bits(_, _, _, acc), do: acc

  defp format_bits(bin) do
    <<a :: size(7), c :: size(1), e :: size(7)>> = Bits.reverse(bin)
    <<b :: size(8), d :: size(7)>> = bin
    <<a :: size(7), b :: size(8), c :: size(1), d :: size(7), 1 :: size(1), e :: size(7)>>
  end

  defp version_bits(bin) do
    vtop = Bits.reverse(bin)
    vleft = version_bits(vtop, [])
    <<vtop :: bitstring, vleft :: bitstring>>
  end
  defp version_bits(<<x :: size(3), bin :: bitstring>>, acc), do:
    version_bits(bin, [x | acc])
  defp version_bits(<<>>, acc), do:
    version_bits(Enum.reverse(acc), <<>>, <<>>, <<>>)

  defp version_bits([<<a :: size(1), b :: size(1), c :: size(1)>> | t], row_a, row_b, row_c), do:
    version_bits(t, <<row_a :: bitstring, a :: size(1)>>, <<row_b :: bitstring, b :: size(1)>>, <<row_c :: bitstring, c :: size(1)>>)
  defp version_bits([], row_a, row_b, row_c), do:
    Bits.append([row_a, row_b, row_c])
end
