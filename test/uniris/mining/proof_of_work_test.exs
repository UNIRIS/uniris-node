defmodule Uniris.Mining.ProofOfWorkTest do
  use UnirisCase

  alias Uniris.Crypto

  alias Uniris.Mining.ProofOfWork

  alias Uniris.P2P
  alias Uniris.P2P.Node

  alias Uniris.SharedSecrets

  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.TransactionData

  doctest ProofOfWork

  describe "list_origin_public_keys_candidates/1 when it's a transaction with smart contract" do
    test "load the origin public keys based on the origin family provided " do
      :ok =
        P2P.add_node(%Node{
          last_public_key: Crypto.node_public_key(0),
          first_public_key: Crypto.node_public_key(0),
          ip: {127, 0, 0, 1},
          port: 3000
        })

      other_public_key = <<0::8, :crypto.strong_rand_bytes(32)::binary>>

      :ok = SharedSecrets.add_origin_public_key(:biometric, other_public_key)
      :ok = SharedSecrets.add_origin_public_key(:software, :crypto.strong_rand_bytes(32))

      tx =
        Transaction.new(
          :transfer,
          %TransactionData{
            code: """
            condition origin_family: biometric
            """
          },
          "seed",
          0
        )

      assert [other_public_key] == ProofOfWork.list_origin_public_keys_candidates(tx)
    end
  end
end
