defmodule QRCode.ReedSolomon do

  alias QRCode.GF256
  require Bitwise

  @qrcode_gf256_prime_modulus 285 # 16#011D

  def encode(bin, degree) when degree > 0 do
    # TODO: field can be generated at compile-time
    field = GF256.field(@qrcode_gf256_prime_modulus)
    generator = generator(field, degree)
    data = :binary.bin_to_list(bin)
    coeffs = GF256.monomial_product(field, data, 1, degree)
    {_quotient, remainder} = GF256.divide(field, coeffs, generator)
    error_correction_bytes = :binary.list_to_bin(remainder)
    <<error_correction_bytes :: binary>>
  end

  def bch_code(byte, poly) do
    msb = msb(poly)
    byte = Bitwise.bsl(byte, (msb - 1))
    bch_code(byte, poly, msb)
  end

  ##

  defp generator(f, d) when d > 0, do:
    generator(f, [1], d, 0)
  defp generator(_, p, d, d), do: p
  defp generator(f, p, d, count) do
    p = GF256.polynomial_product(f, p, [1, GF256.exponent(f, count)])
    generator(f, p, d, count + 1)
  end

  defp bch_code(byte, poly, msb) do
    case msb(byte) >= msb do
      true -> bch_code(Bitwise.bxor(byte, Bitwise.bsl(poly, (msb(byte) - msb))), poly, msb)
      false -> byte
    end
  end

  defp msb(0), do: 0
  defp msb(byte), do: msb(byte, 0)
  defp msb(0, count), do: count
  defp msb(byte, count), do: msb(Bitwise.bsr(byte, 1), count + 1)

end
