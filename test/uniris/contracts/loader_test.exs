defmodule Uniris.Contracts.LoaderTest do
  use ExUnit.Case

  alias Uniris.ContractRegistry
  alias Uniris.Contracts.Contract
  alias Uniris.Contracts.Contract.Constants
  alias Uniris.Contracts.Contract.Trigger
  alias Uniris.Contracts.Loader
  alias Uniris.Contracts.Worker
  alias Uniris.ContractSupervisor

  alias Uniris.Crypto

  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.TransactionData

  import Mox

  setup :set_mox_global

  describe "load_transaction/1" do
    test "should create a supervised worker for the given transaction with contract code" do
      tx = %Transaction{
        address: "@SC1",
        data: %TransactionData{
          code: """
          actions triggered_by: transaction do end 
          """
        },
        previous_public_key: ""
      }

      assert :ok = Loader.load_transaction(tx)
      [{pid, _}] = Registry.lookup(ContractRegistry, "@SC1")

      assert Enum.any?(
               DynamicSupervisor.which_children(ContractSupervisor),
               &match?({_, ^pid, :worker, [Worker]}, &1)
             )

      assert %{
               contract: %Contract{
                 triggers: [%Trigger{type: :transaction, actions: {:__block__, [], []}}],
                 constants: %Constants{contract: [{:address, "@SC1"} | _]}
               }
             } = :sys.get_state(pid)
    end

    test "should stop a previous contract for the same chain" do
      tx1 = %Transaction{
        address: Crypto.hash("Alice2"),
        data: %TransactionData{
          code: """
          actions triggered_by: transaction do end 
          """
        },
        previous_public_key: "Alice1"
      }

      tx2 = %Transaction{
        address: Crypto.hash("Alice3"),
        data: %TransactionData{
          code: """
          actions triggered_by: transaction do end 
          """
        },
        previous_public_key: "Alice2"
      }

      assert :ok = Loader.load_transaction(tx1)
      [{pid1, _}] = Registry.lookup(ContractRegistry, tx1.address)
      assert :ok = Loader.load_transaction(tx2)
      [{pid2, _}] = Registry.lookup(ContractRegistry, tx2.address)

      assert !Process.alive?(pid1)
      assert Process.alive?(pid2)

      assert Enum.any?(
               DynamicSupervisor.which_children(ContractSupervisor),
               &match?({_, ^pid2, :worker, [Worker]}, &1)
             )
    end
  end

  test "start_link/1 should load smart contract from DB" do
    MockDB
    |> stub(:list_transactions, fn _ ->
      [
        %Transaction{
          address: "@SC2",
          data: %TransactionData{
            code: """
            actions triggered_by: transaction do end 
            """
          },
          previous_public_key: ""
        }
      ]
    end)

    assert {:ok, _} = Loader.start_link()
    [{pid, _}] = Registry.lookup(ContractRegistry, "@SC2")

    assert Enum.any?(
             DynamicSupervisor.which_children(ContractSupervisor),
             &match?({_, ^pid, :worker, [Worker]}, &1)
           )

    assert %{
             contract: %Contract{
               triggers: [%Trigger{type: :transaction, actions: {:__block__, [], []}}],
               constants: %Constants{contract: [{:address, "@SC2"} | _]}
             }
           } = :sys.get_state(pid)
  end
end
