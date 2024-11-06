defmodule Crypt.Hkdf do
  @moduledoc """
  Documentation for `Hkdf`.
  """

  @doc """
  Derives a key from an input key material.

  ## Examples

      iex> input = Base.decode16!("784587B71309D1C4774F6FDF9FE5160753C40EF67F145CA62177C6CA36C2151D")
      iex> length = 32
      iex> salt = Base.decode16!("48EA16CCF2829D493F9ADBADE344F061")
      iex> info = "info"
      iex> key = Crypt.Hkdf.derive(input, length, salt, info)
      key
  """

  def derive(input, length, salt \\ "", info \\ "") do
    prk = extract(input, salt)
    okm = expand(prk, info, length)

    okm
  end

  defp extract(input, salt) do
    prk = :crypto.mac(:hmac, :sha512, salt, input)

    prk
  end

  defp expand(prk, info, length) do
    hash_length = 64

    n = Float.ceil(length / hash_length) |> round()

    full =
      Enum.scan(1..n, "", fn index, prev ->
        data = prev <> info <> <<index>>
        :crypto.mac(:hmac, :sha512, prk, data)
      end)
      |> Enum.reduce("", &Kernel.<>(&2, &1))

    <<output::unit(8)-size(length), _::binary>> = full
    <<output::unit(8)-size(length)>>
  end
end
