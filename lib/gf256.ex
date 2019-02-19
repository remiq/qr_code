defmodule QRCode.GF256 do
  @moduledoc """
  Galois field(256)
  https://en.wikipedia.org/wiki/Finite_field
  https://github.com/komone/qrcode/blob/master/src/gf256.erl
  """
  defstruct exponent: nil, log: nil

  alias QRCode.GF256
  require Bitwise

  @range 255

  def field(prime_modulus) do
    exponent = exponent_table(1, prime_modulus, [])
    %GF256{
      exponent: exponent,
      log: log_table(exponent, 1, [0])
    }
  end

  defp exponent_table(x, modulus, acc) when length(acc) <= @range do
    x0 = case Bitwise.bsl(x, 1) do
      v when v > @range -> Bitwise.bxor(v, modulus)
      v -> v
    end
    exponent_table(x0, modulus, [x|acc])
  end
  defp exponent_table(_, _, acc), do: Enum.reverse(acc)

  defp log_table(e, count, acc) when count <= @range do
    x = index_of(count, 0, e)
    log_table(e, count + 1, [x | acc])
  end
  defp log_table(_, _, acc), do: Enum.reverse(acc)

  defp index_of(x, count, [x|_]), do: count
  defp index_of(x, count, [_|t]), do: index_of(x, count + 1, t)

  def add(%GF256{}, a, b) when is_integer(a) and is_integer(b), do:
    Bitwise.bxor(a, b)
  def add(%GF256{}, [0], b) when is_list(b), do: b
  def add(%GF256{}, a, [0]) when is_list(a), do: a
  def add(%GF256{} = f, a, b) when is_list(a) and is_list(b), do:
    add(f, Enum.reverse(a), Enum.reverse(b), [])

  defp add(f, [h|t], [h0|t0], acc), do:
    add(f, t, t0, [Bitwise.bxor(h, h0) | acc])
  defp add(f, [h|t], [], acc), do:
    add(f, t, [], [h|acc])
  defp add(f, [], [h|t], acc), do:
    add(f, [], t, [h|acc])
  defp add(_, [], [], acc), do: acc

  def subtract(%GF256{} = f, a, b), do:
    add(f, a, b)

  def multiply(%GF256{}, 0, _), do: 0
  def multiply(%GF256{}, _, 0), do: 0
  def multiply(%GF256{} = f, a, b) do
    x = rem(log(f, a) + log(f, b), @range)
    exponent(f, x)
  end

  def exponent(%GF256{exponent: e}, n), do:
    Enum.at(e, n)

  def log(%GF256{log: l}, n), do:
    Enum.at(l, n)

  def inverse(%GF256{} = f, x), do:
    exponent(f, @range - log(f, x))

  def value(%GF256{}, poly, 0), do:
    List.last(poly)
  def value(%GF256{} = f, poly, 1), do:
    List.foldl(poly, 0, fn x, sum -> add(f, x, sum) end)
  def value(%GF256{} = f, [h|t], x), do:
    value(f, t, x, h)

  defp value(f, [h|t], x, acc) do
    acc = multiply(f, x, acc)
    acc = add(f, acc, h)
    value(f, t, x, acc)
  end
  defp value(_, [], _, acc), do: acc

  def monomial(%GF256{}, 0, degree) when degree >= 0, do: [0]
  def monomial(%GF256{}, coeff, degree) when degree >= 0, do:
    [coeff | List.duplicate(0, degree)]

  def monomial_product(f, poly, coeff, degree), do:
    monomial_product(f, poly, coeff, degree, [])

  defp monomial_product(f, [h|t], c, d, acc) do
    p = GF256.multiply(f, h, c)
    monomial_product(f, t, c, d, [p | acc])
  end
  defp monomial_product(f, [], c, d, acc) when d > 0, do:
    monomial_product(f, [], c, d - 1, [0|acc])
  defp monomial_product(_, [], _, 0, acc), do: Enum.reverse(acc)

  def polynomial_product(_, [0], _), do: [0]
  def polynomial_product(_, _, [0]), do: [0]
  def polynomial_product(f, p0, p1), do:
    polynomial_product0(f, p0, p1, [], [])

  defp polynomial_product0(f, [h|t], p1, p2, acc) do
    [h0|t0] = polynomial_product1(f, h, p1, p2, [])
    polynomial_product0(f, t, p1, t0, [h0|acc])
  end
  defp polynomial_product0(f, [], p1, [h|t], acc), do:
    polynomial_product0(f, [], p1, t, [h|acc])
  defp polynomial_product0(_, [], _, [], acc), do:
    Enum.reverse(acc)

  defp polynomial_product1(_, _, [], [], acc), do:
    Enum.reverse(acc)
  defp polynomial_product1(f, x, [h|t], [], acc) do
    coeff = polynomial_product2(f, x, h, 0)
    polynomial_product1(f, x, t, [], [coeff|acc])
  end
  defp polynomial_product1(f, x, [h|t], [h0|t0], acc) do
    coeff = polynomial_product2(f, x, h, h0)
    polynomial_product1(f, x, t, t0, [coeff|acc])
  end

  defp polynomial_product2(f, x, h, h0) do
    coeff = multiply(f, x, h)
    add(f, h0, coeff)
  end

  def divide(%GF256{} = f, a, [h|_] = b) when b != [0] do
    idlt = inverse(f, h)
    divide(f, idlt, b, [0], a)
  end
  defp divide(f, idlt, b, q, [h|_] = r)
    when length(r) >= length(b) and r != [0] do
      diff = length(r) - length(b)
      scale = multiply(f, h, idlt)
      m = monomial(f, scale, diff)
      q = add(f, q, m)
      coeffs = monomial_product(f, b, scale, diff)
      [_|r] = add(f, r, coeffs)
      divide(f, idlt, b, q, r)
  end
  defp divide(_, _, _, q, r), do: {q, r}

end
