defmodule Uniris.P2P.MemTableLoader do
  @moduledoc false

  use GenServer

  alias Uniris.P2P
  alias Uniris.P2P.GeoPatch
  alias Uniris.P2P.MemTable
  alias Uniris.P2P.Node

  alias Uniris.SharedSecrets

  alias Uniris.TransactionChain
  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.Transaction.ValidationStamp
  alias Uniris.TransactionChain.TransactionData
  alias Uniris.TransactionChain.TransactionData.Keys

  require Logger

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    TransactionChain.list_transactions_by_type(:node, [
      :address,
      :timestamp,
      :type,
      :previous_public_key,
      data: [:content],
      validation_stamp: [:timestamp]
    ])
    |> Stream.each(&load_transaction/1)
    |> Stream.run()

    last_node_shared_secret_tx =
      TransactionChain.list_transactions_by_type(:node_shared_secrets, [
        :type,
        data: [:keys],
        validation_stamp: [:timestamp]
      ])
      |> Enum.at(0)

    case last_node_shared_secret_tx do
      nil ->
        {:ok, []}

      tx ->
        load_transaction(tx)
        {:ok, []}
    end
  end

  @doc """
  Load the transaction and update the P2P view
  """
  @spec load_transaction(Transaction.t()) :: :ok
  def load_transaction(%Transaction{
        address: address,
        type: :node,
        previous_public_key: previous_public_key,
        data: %TransactionData{content: content},
        validation_stamp: %ValidationStamp{
          timestamp: timestamp
        }
      }) do
    first_public_key = TransactionChain.get_first_public_key(previous_public_key)
    {ip, port, transport, reward_address} = extract_node_endpoint(content)

    node = %Node{
      ip: ip,
      port: port,
      first_public_key: first_public_key,
      last_public_key: previous_public_key,
      geo_patch: GeoPatch.from_ip(ip),
      transport: transport,
      last_address: address,
      reward_address: reward_address
    }

    if first_node_change?(first_public_key, previous_public_key) do
      node
      |> Node.enroll(timestamp)
      |> MemTable.add_node()
    else
      MemTable.add_node(node)
    end

    Logger.debug("Loaded into in memory p2p tables", node: Base.encode16(first_public_key))
  end

  def load_transaction(%Transaction{
        type: :node_shared_secrets,
        data: %TransactionData{keys: keys},
        validation_stamp: %ValidationStamp{
          timestamp: timestamp
        }
      }) do
    new_authorized_keys = Keys.list_authorized_keys(keys)
    previous_authorized_keys = P2P.authorized_nodes() |> Enum.map(& &1.last_public_key)

    unauthorized_keys = previous_authorized_keys -- new_authorized_keys

    Enum.each(unauthorized_keys, &MemTable.unauthorize_node/1)

    keys
    |> Keys.list_authorized_keys()
    |> Enum.map(&MemTable.get_first_node_key/1)
    |> Enum.each(&MemTable.authorize_node(&1, SharedSecrets.next_application_date(timestamp)))
  end

  def load_transaction(_), do: :ok

  defp first_node_change?(first_key, previous_key) when first_key == previous_key, do: true
  defp first_node_change?(_, _), do: false

  defp extract_node_endpoint(content) do
    [[ip_match, port_match, transport_match, reward_address_match]] =
      Regex.scan(Node.transaction_content_regex(), content, capture: :all_but_first)

    {:ok, ip} =
      ip_match
      |> String.trim()
      |> String.to_charlist()
      |> :inet.parse_address()

    port =
      port_match
      |> String.trim()
      |> String.to_integer()

    transport =
      transport_match
      |> String.trim()
      |> String.to_existing_atom()

    reward_address =
      reward_address_match
      |> String.trim()
      |> Base.decode16!()

    {ip, port, transport, reward_address}
  end
end
