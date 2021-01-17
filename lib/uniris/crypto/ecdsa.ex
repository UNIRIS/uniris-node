defmodule Uniris.Crypto.ECDSA do
  @moduledoc false

  @type curve :: :secp256r1 | :secp256k1

  @curves [:secp256r1, :secp256k1]

  @doc """
  Generate an ECDSA keypair from a given secrets
  """
  @spec generate_keypair(curve(), binary()) :: {binary(), binary()}
  def generate_keypair(curve, seed)
      when curve in @curves and is_binary(seed) and byte_size(seed) < 32 do
    :crypto.generate_key(
      :ecdh,
      curve,
      :crypto.hash(:sha256, seed)
    )
  end

  def generate_keypair(curve, seed) when curve in @curves and is_binary(seed) do
    :crypto.generate_key(
      :ecdh,
      curve,
      :binary.part(seed, 0, 32)
    )
  end

  @doc """
  Sign a data with the given private key
  """
  @spec sign(curve(), binary(), iodata()) :: binary()
  def sign(curve, private_key, data)
      when curve in @curves and (is_binary(data) or is_list(data)) and is_binary(private_key) do
    :crypto.sign(:ecdsa, :sha256, :crypto.hash(:sha256, data), [
      private_key,
      curve
    ])
  end

  @doc """
  Verify a signature using the given public key and data
  """
  @spec verify(curve(), binary(), iodata(), binary()) :: boolean()
  def verify(curve, public_key, data, sig)
      when curve in @curves and (is_binary(data) or is_list(data)) and is_binary(sig) do
    :crypto.verify(
      :ecdsa,
      :sha256,
      :crypto.hash(:sha256, data),
      sig,
      [
        public_key,
        curve
      ]
    )
  end

  @doc """
  Encrypt a data using the public key through ECIES
  """
  @spec encrypt(curve(), binary(), binary()) :: binary()
  def encrypt(curve, public_key, message)
      when curve in @curves and is_binary(message) and is_binary(public_key) do
    {ephemeral_public_key, ephemeral_private_key} = :crypto.generate_key(:ecdh, curve)

    # Derivate secret using ECDH with the given public key and the ephemeral private key
    shared_key = generate_dh_key(curve, public_key, ephemeral_private_key)

    # Generate keys for the AES authenticated encryption
    {iv, aes_key} = derivate_secrets(shared_key)

    {cipher, tag} = aes_auth_encrypt(iv, aes_key, message)

    # Encode the cipher within the ephemeral public key, the authentication tag
    ephemeral_public_key <> tag <> cipher
  end

  @doc """
  Decrypt a ciphertext using the given private through ECIES

  Raise if the decryption failed
  """
  @spec decrypt(curve(), binary(), binary()) :: binary()
  def decrypt(
        curve,
        private_key,
        _encoded_cipher = <<ephemeral_public_key::binary-65, tag::binary-16, cipher::binary>>
      ) do
    # Derivate shared key using ECDH with the given ephermal public key and the private key
    shared_key = generate_dh_key(curve, ephemeral_public_key, private_key)

    # Generate keys for the AES authenticated decryption
    {iv, aes_key} = derivate_secrets(shared_key)

    case aes_auth_decrypt(iv, aes_key, cipher, tag) do
      :error ->
        raise "Decryption failed"

      data ->
        data
    end
  end

  defp generate_dh_key(curve, public_key, private_key),
    do: :crypto.compute_key(:ecdh, public_key, private_key, curve)

  defp derivate_secrets(dh_key) do
    pseudorandom_key = :crypto.hmac(:sha256, "", dh_key)
    iv = binary_part(:crypto.hmac(:sha256, pseudorandom_key, "0"), 0, 32)
    aes_key = binary_part(:crypto.hmac(:sha256, iv, "1"), 0, 32)
    {iv, aes_key}
  end

  defp aes_auth_encrypt(iv, key, data),
    do: :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, data, "", true)

  defp aes_auth_decrypt(iv, key, cipher, tag),
    do: :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, cipher, "", tag, false)
end
