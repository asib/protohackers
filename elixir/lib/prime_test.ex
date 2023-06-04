defmodule PrimeTest do
  @moduledoc """
  Implementation of Miller-Rabin-test.

  This module provides the primality test based on
  Miller-Rabin's method.

  The methodology is essentially probablistic.
  See the doc of `Prime.Fermat` for details.

  The unignorable difference between fermat-test and
  miller-rabin-test is that the latter defeats Carmichael
  numbers while giving up no efficiency. You might
  feel easier to reason towards employing this algorithm
  than the fermat-test, although they are equally great
  formulations of the intrinsic nature of numbers.
  """

  # Copied from https://raw.githubusercontent.com/sato11/prime/main/lib/prime/miller_rabin.ex

  @iterations 128

  @doc """
  Returns the result of miller-rabin-test.

  ## Examples

      iex> Prime.MillerRabin.test(1)
      false

      iex> Prime.MillerRabin.test(2)
      true

      iex> Prime.MillerRabin.test(3)
      true

      iex> Prime.MillerRabin.test(42)
      false

      iex> Prime.MillerRabin.test(561)
      false # won't get fooled by the first carmichael number.

  """
  @spec test(pos_integer()) :: boolean()
  def test(n) when n < 2, do: false

  def test(n) when n == 2, do: true

  def test(n) do
    do_test(n, @iterations)
  end

  defp do_test(_, 0), do: true

  defp do_test(n, k) do
    p = Enum.random(2..(n - 1))

    if powmod_with_check(p, n - 1, n) == 1 do
      do_test(n, k - 1)
    else
      false
    end
  end

  defp powmod_with_check(_, 0, _), do: 1

  defp powmod_with_check(base, exp, mod) when rem(exp, 2) == 0 do
    case powmod_with_check(base, div(exp, 2), mod) do
      x when rem(x * x, mod) == 1 and x != 1 and x != mod - 1 -> 0
      x -> rem(x * x, mod)
    end
  end

  defp powmod_with_check(base, exp, mod) do
    rem(base * powmod_with_check(base, exp - 1, mod), mod)
  end
end
