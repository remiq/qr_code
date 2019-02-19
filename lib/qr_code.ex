defmodule QRCode do
  @moduledoc """
  Creates QR codes.
  https://github.com/komone/qrcode/blob/master/src/qrcode.erl
  """
  defstruct version: nil,
    ecc: nil,
    dimension: nil,
    data: []

  alias QRCode.Params
  alias QRCode.ECC

  @quiet_zone 4
  @byte_mode 4
  @cci_bitsize %{
    numeric_mode: [10, 12, 14],
    alphanumeric_mode: [9, 11, 13],
    byte_mode: [8, 16, 16],
    kanji_mode: [8, 16, 16]
  }

  @doc """
  Encodes `bin` binary using `ecc` Error Correction Level.

  ECC values:
  - 'L': recovers 7% of data
  - 'M': recovers 15% of data (default)
  - 'Q': recovers 25% of data
  - 'H': recovers 30% of data
  """
  def encode(bin, ecc \\ 'M') do
    params = Params.choose_qr_params(bin, ecc)
    content = encode_content(params, bin)
    blocks_with_ecc = ECC.generate_ecc_blocks(params, content)
    codewords = interleave_blocks(blocks_with_ecc)
    matrix = QRCode.Matrix.embed_data(params, codewords)
    masked_matrices = QRCode.Mask.generate(params, matrix)
    candidates = Enum.map(masked_matrices, fn m -> QRCode.Matrix.overlay_static(params, m) end)
    {mask_type, selected_matrix} = QRCode.Mask.select(candidates)
    params = %Params{ params |
      mask: mask_type}
    fmt = Params.format_info_bits(params)
    vsn = Params.version_info_bits(params)
    %Params{
      version: version,
      dimension: dim,
      ec_level: _ecc
    } = params
    data = QRCode.Matrix.finalize(dim, fmt, vsn, @quiet_zone, selected_matrix)
    %QRCode{
      version: version,
      ecc: ecc,
      dimension: dim + @quiet_zone * 2,
      data: data
    }
  end

  defp encode_content(%Params{mode: mode, version: version}, string), do:
    encode_content(mode, version, string)

  defp encode_content(:byte, version, string), do:
    encode_bytes(version, string)

  defp interleave_blocks(blocks) do
    data = interleave_data(blocks, <<>>)
    interleave_ecc(blocks, data)
  end

  defp interleave_data(blocks, bin) do
    data = Enum.map(blocks, fn {x, _} -> x end)
    interleave_blocks(data, [], bin)
  end

  defp interleave_ecc(blocks, bin) do
    data = Enum.map(blocks, fn {_, x} -> x end)
    interleave_blocks(data, [], bin)
  end

  defp interleave_blocks([], [], bin), do: bin
  defp interleave_blocks([], acc, bin) do
    acc = acc
      |> Enum.filter(fn x -> x != <<>> end)
    interleave_blocks(Enum.reverse(acc), [], bin)
  end
  defp interleave_blocks([<<x, data :: binary>> | t], acc, bin), do:
    interleave_blocks(t, [data | acc], <<bin :: binary, x>>)

  defp encode_bytes(version, bin) when is_binary(bin) do
    size = byte_size(bin)
    character_count_bit_size = cci(@byte_mode, version)
    <<@byte_mode :: size(4), size :: size(character_count_bit_size), bin :: binary, 0 :: size(4)>>
  end

  # character count indicator
  defp cci(mode, version) when version >= 1 and version <= 40 do
    mode = cci_mode(mode)
    cc = Map.get(@cci_bitsize, mode)
    case {cc, version} do
      {[x, _, _], version} when version <= 9 -> x
      {[_, x, _], version} when version <= 26 -> x
      {[_, _, x], _} -> x
    end
  end

  defp cci_mode(0b0001), do: :numeric_mode
  defp cci_mode(0b0010), do: :alphanumeric_mode
  defp cci_mode(0b0100), do: :byte_mode
  defp cci_mode(0b1000), do: :kanji_mode
  defp cci_mode(0b0111), do: :eci_mode

  #def png(data)

  @doc """
  Returns QR code as string of {\#, \.}.
  """
  def as_string(string) do
    %QRCode{data: data, dimension: dimension} = encode(string)
    data
    |> to_chars()
    |> Enum.chunk_every(dimension)
    |> Enum.join("\n")
    |> (fn s -> s <> "\n" end).()
  end

  defp to_chars(list), do: to_chars(list, [])
  defp to_chars(<< 0 :: size(1), tail :: bitstring >>, acc), do:
    to_chars(tail, ["." | acc])
  defp to_chars(<< 1 :: size(1), tail :: bitstring >>, acc), do:
    to_chars(tail, ["#" | acc])
  defp to_chars(<<>>, acc), do: Enum.reverse(acc)

  @doc """
  Creates QR code and displays it in terminal.
  """
  def print(string) do
    string
    |> as_string()
    |> display()
  end

  defp display(as_string) do
    white = IO.ANSI.white_background() <> " "
    black = IO.ANSI.black_background() <> " "
    nl = IO.ANSI.reset() <> "\n"
    as_string
    |> String.replace("#", black)
    |> String.replace(".", white)
    |> String.replace("\n", nl)
    |> IO.puts
  end
end
