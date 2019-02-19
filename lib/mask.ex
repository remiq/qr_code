defmodule QRCode.Mask do
  #generate
  #select
  # todo: https://github.com/komone/qrcode/blob/master/src/qrcode_mask.erl

  alias QRCode.Params
  require Bitwise

  @penalty_rule_1 3
  @penalty_rule_2 3
  @penalty_rule_3 40
  @penalty_rule_4 10

  def generate(%Params{dimension: dimension}, matrix) do
    0..7
      |> Enum.map(fn x -> mask(x) end)
      |> Enum.map(fn mf -> generate_mask(dimension, mf) end)
      |> Enum.map(fn mask -> apply_mask(matrix, mask, []) end)
  end

  def select([h | t]) do
    score = score_candidate(h)
    select_candidate(t, 0, 0, score, h)
  end

  defp generate_mask(max, mf) do
    seq = 0..(max - 1)
    Enum.map(seq, fn y -> generate_mask(seq, y, mf) end)
  end
  defp generate_mask(seq, y, mf) do
    Enum.map(seq, fn x ->
      case mf.(x, y) do
        true -> 1
        false -> 0
      end
    end)
  end

  defp apply_mask([h|t], [h0|t0], acc) do
    row = apply_mask0(h, h0, [])
    apply_mask(t, t0, [row|acc])
  end
  defp apply_mask([], [], acc), do: Enum.reverse(acc)

  defp apply_mask0([h|t], [h0|t0], acc) when is_integer(h), do:
    apply_mask0(t, t0, [Bitwise.bxor(h, h0) | acc])
  defp apply_mask0([h|t], [_|t0], acc), do:
    apply_mask0(t, t0, [h|acc])
  defp apply_mask0([], [], acc), do: Enum.reverse(acc)

  defp mask(0), do: fn x, y -> rem(x + y, 2) == 0 end
  defp mask(1), do: fn _, y -> rem(y, 2) == 0 end
  defp mask(2), do: fn x, _ -> rem(x, 3) == 0 end
  defp mask(3), do: fn x, y -> rem(x + y, 3) == 0 end
  defp mask(4), do: fn x, y -> rem(div(x, 3) + div(y, 2), 2) == 0 end
  defp mask(5), do: fn x, y ->
    sum = x * y
    rem(sum, 2) + rem(sum, 3) == 0
  end
  defp mask(6), do: fn x, y ->
    sum = x * y
    rem(rem(sum, 2) + rem(sum, 3), 2) == 0
  end
  defp mask(7), do: fn x, y ->
    rem(rem(x * y, 3) + rem(x + y, 2), 2) == 0 end

  defp select_candidate([h|t], count, mask, score, c) do
    case score_candidate(h) do
      x when x < score -> select_candidate(t, count + 1, count + 1, x, h)
      _ -> select_candidate(t, count + 1, mask, score, c)
    end
  end
  defp select_candidate([], _, mask, _score, c), do:
    {mask, c}

  defp score_candidate(c) do
    rule1 = apply_penalty_rule_1(c)
    rule2 = apply_penalty_rule_2(c)
    rule3 = apply_penalty_rule_3(c)
    rule4 = apply_penalty_rule_4(c)
    rule1 + rule2 + rule3 + rule4
  end

  defp apply_penalty_rule_1(candidate) do
    score_rows = rule1(candidate, 0)
    score_cols = rule1(rows_to_columns(candidate), 0)
    score_cols + score_rows
  end

  defp rule1([row|t], score) do
    score = rule1_row(row, score)
    rule1(t, score)
  end
  defp rule1([], score), do: score

  defp rule1_row(l = [h|_], score) do
    f = fn
      1 when h == 1 -> true
      1 -> false
      _ when h == 0 or not is_integer(h) -> true
      _ -> false
    end
    {h, t} = Enum.split_with(l, f)
    case length(h) do
      repeats when repeats >= 5 ->
        penalty = @penalty_rule_1 + repeats - 5
        rule1_row(t, score + penalty)
      _ -> rule1_row(t, score)
    end
  end
  defp rule1_row([], score), do: score

  defp apply_penalty_rule_2([h, h0 | t]) do
    rule2(1, 1, h, h0, [h0|t], [])
    |> composite_blocks([])
    |> composite_blocks([])
    |> Enum.reduce(0, fn
      {_, {m, n}, _}, acc ->
        @penalty_rule_2 * (m - 1) * (n - 1) + acc
    end)
  end

  defp rule2(x, y, [h, h | t], [h, h | t0], rows, acc), do:
    rule2(x + 1, y, [h|t], [h|t0], rows, [{{x,y}, {2,2}, h} | acc])
  defp rule2(x, y, [_|t], [_|t0], rows, acc), do:
    rule2(x + 1, y, t, t0, rows, acc)
  defp rule2(_, y, [], [], [h, h0|t], acc), do:
    rule2(1, y + 1, h, h0, [h0|t], acc)
  defp rule2(_, _, [], [], [_], acc), do: Enum.reverse(acc)

  defp composite_blocks([h|t], acc) do
    {h, t} = composite_block(h, t, [])
    composite_blocks(t, [h|acc])
  end
  defp composite_blocks([], acc), do: Enum.reverse(acc)

  defp composite_block(b, [h|t], acc) do
    case combine_block(b, h) do
      false -> composite_block(b, t, [h|acc])
      b -> composite_block(b, t, acc)
    end
  end
  defp composite_block(b, [], acc), do:
    {b, Enum.reverse(acc)}


defp combine_block(b = {{x, y}, {sx, sy}, _}, b0 = {{x0, y0}, _, _})
  when x0 < x + sx or y0 < y + sy, do:
    combine_block0(b, b0)
defp combine_block(_, _), do: false

defp combine_block0(b = {_, _, v}, b0 = {_, _, v0})
  when v == v0 or (v != 1 and v0 != 1), do:
    combine_block1(b, b0)
defp combine_block0(_, _), do: false

defp combine_block1({{x, y}, {sx, sy}, v}, {{x0, y}, {sx0, sy}, _}) when x0 == x + sx - 1 do
  {{x, y}, {sx + sx0 - 1, sy}, v}
end
defp combine_block1({{x, y}, {sx, sy}, v}, {{x, y0}, {sx, sy0}, _}) when y0 == y + sy - 1 do
  {{x, y}, {sx, sy + sy0 - 1}, v}
end
defp combine_block1(_, _), do: false

defp apply_penalty_rule_3(candidate) do
  row_scores = candidate
    |> Enum.map(fn row -> rule3(row, 0) end)
  column_scores = candidate
    |> rows_to_columns()
    |> Enum.map(fn row -> rule3(row, 0) end)
  Enum.sum(row_scores) + Enum.sum(column_scores)
end

defp rule3(row = [1|t], score) do
  ones = Enum.take_while(row, fn x -> x == 1 end)
  scale = length(ones)
  case scale * 7 do
    length when length > length(row) -> rule3(t, score)
    length ->
      case is_11311_pattern(Enum.slice(row, 0, length), scale) do
        true -> rule3(t, score + @penalty_rule_3)
        false -> rule3(t, score)
      end
  end
end
defp rule3([_|t], acc), do: rule3(t, acc)
defp rule3([], acc), do: acc

defp is_11311_pattern(list, scale) do
  list = Enum.map(list, fn
    x when x == 1 -> 1
    _ -> 0
  end)
  result = condense(list, scale, [])
  result == [1, 0, 1, 1, 1, 0, 1]
end

defp condense([], _, acc), do: Enum.reverse(acc)
defp condense(l, scale, acc) do
  {h, t} = Enum.split(l, scale)
  case Enum.sum(h) do
    ^scale -> condense(t, scale, [1|acc])
    0 -> condense(t, scale, [0|acc])
    _ -> nil
  end
end

defp apply_penalty_rule_4(candidate) do
  proportion = rule4(candidate, 0, 0)
  @penalty_rule_4 * div(trunc(abs(proportion * 100 - 50)), 5)
end

defp rule4([h|t], dark, all) do
  all = all + length(h)
  dark = dark + Enum.count(h, fn x -> x == 1 end)
  rule4(t, dark, all)
end
defp rule4([], dark, all), do: dark / all

defp rows_to_columns(l), do: rows_to_columns(l, [])
defp rows_to_columns([[]|_], acc), do: Enum.reverse(acc)
defp rows_to_columns(l, acc) do
  heads = Enum.map(l, fn [h|_] -> h end)
  tails = Enum.map(l, fn [_|t] -> t end)
  rows_to_columns(tails, [heads|acc])
end

end
