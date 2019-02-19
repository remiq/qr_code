defmodule QRCode.ECC do
  @data_pad_0 236 # 11101100
  @data_pad_1 17  # 00010001

  alias QRCode.Params
  require Bitwise

  def generate_ecc_blocks(%Params{block_defs: block_defs}, bin) do
    bin_padded = pad_data(bin, block_defs)
    generate_ecc(bin_padded, block_defs, [])
  end

  defp pad_data(bin, ecc_block_defs) do
    data_size = byte_size(bin)
    total_size = get_ecc_size(ecc_block_defs)
    padding_size = total_size - data_size
    padding = :binary.copy(<< @data_pad_0, @data_pad_1>>, Bitwise.bsr(padding_size, 1))
    case Bitwise.band(padding_size, 1) do
      0 -> <<bin :: binary, padding :: binary>>
      1 -> <<bin :: binary, padding :: binary, @data_pad_0>>
    end
  end

  defp get_ecc_size(ecc_block_defs), do:
    get_ecc_size(ecc_block_defs, 0)
  defp get_ecc_size([{c, _, d} | t], acc), do:
    get_ecc_size(t, c * d + acc)
  defp get_ecc_size([], acc), do: acc

  defp generate_ecc(bin, [{c, l, d} | t], acc) do
    {result, bin} = generate_ecc0(bin, c, l, d, [])
    generate_ecc(bin, t, [result | acc])
  end
  defp generate_ecc(<<>>, [], acc), do:
    acc |> Enum.reverse |> List.flatten

  defp generate_ecc0(bin, count, total_length, block_length, acc) when byte_size(bin) >= block_length and count > 0 do
    <<block :: binary-size(block_length), bin :: binary>> = bin
    ec = QRCode.ReedSolomon.encode(block, total_length - block_length)
    generate_ecc0(bin, count - 1, total_length, block_length, [{block, ec} | acc])
  end
  defp generate_ecc0(bin, 0, _, _, acc), do:
    {Enum.reverse(acc), bin}
end
