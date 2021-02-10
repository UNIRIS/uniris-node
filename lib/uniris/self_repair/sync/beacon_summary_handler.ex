defmodule Uniris.SelfRepair.Sync.BeaconSummaryHandler do
  @moduledoc false

  alias Uniris.BeaconChain
  alias Uniris.BeaconChain.Summary, as: BeaconSummary

  alias Uniris.Crypto

  alias Uniris.DB

  alias Uniris.Election

  alias Uniris.P2P
  alias Uniris.P2P.Message.GetBeaconSummary

  alias __MODULE__.NetworkStatistics
  alias __MODULE__.TransactionHandler

  alias Uniris.TransactionChain

  alias Uniris.Utils

  require Logger

  @doc """
  Retrieve the list of missed beacon summaries from a given date.

  It request every subsets to find out the missing ones by query beacon pool nodes.
  """
  @spec get_beacon_summaries(BeaconChain.summary_pools(), binary()) :: Enumerable.t()
  def get_beacon_summaries(summary_pools, patch) when is_binary(patch) do
    Task.async_stream(summary_pools, fn {subset, nodes_by_summary_time} ->
      Task.async_stream(
        nodes_by_summary_time,
        fn {summary_time, nodes} -> do_fetch_summary(subset, summary_time, nodes, patch) end,
        ordered: false
      )
      |> Stream.reject(&match?({:ok, nil}, &1))
      |> Enum.map(fn {:ok, res} -> res end)
    end)
    |> Enum.flat_map(fn {:ok, res} -> res end)
  end

  defp do_fetch_summary(subset, summary_time, nodes, patch) do
    if Utils.key_in_node_list?(nodes, Crypto.node_public_key(0)) do
      case DB.get_beacon_summary(subset, summary_time) do
        {:ok, summary} ->
          summary

        _ ->
          nil
      end
    else
      nodes
      |> Enum.reject(&(&1.first_public_key == Crypto.node_public_key(0)))
      |> P2P.nearest_nodes(patch)
      |> P2P.broadcast_message(%GetBeaconSummary{subset: subset, date: summary_time})
      |> Stream.filter(&match?(%BeaconSummary{}, &1))
      |> Enum.at(0)
    end
  end

  @doc """
  Process beacon slots to synchronize the transactions involving.

  Each transactions from the beacon slots will be analyzed to determine
  if the node is a storage node for this transaction. If so, it will download the
  transaction from the closest storage nodes and replicate it locally.

  The P2P view will also be updated if some node information are inside the beacon slots
  """
  @spec handle_missing_summaries(Enumerable.t() | list(BeaconSummary.t()), binary()) :: :ok
  def handle_missing_summaries(summaries, node_patch) when is_binary(node_patch) do
    load_summaries_in_db(summaries)

    %{
      end_of_node_synchronizations: end_of_node_synchronizations,
      transaction_summaries: transaction_summaries,
      nb_transactions_by_time: nb_transactions_by_time
    } = flatten_summaries(summaries)

    synchronize_transactions(transaction_summaries, node_patch)
    Enum.each(end_of_node_synchronizations, &P2P.set_node_globally_available(&1.public_key))

    update_statistics(nb_transactions_by_time)
  end

  defp update_statistics(nb_transactions_by_date) do
    Enum.map(nb_transactions_by_date, fn {date, nb_transactions} ->
      previous_summary_time =
        date
        |> Utils.truncate_datetime()
        |> BeaconChain.previous_summary_time()

      nb_seconds = abs(DateTime.diff(previous_summary_time, date))
      {date, nb_transactions / nb_seconds, nb_transactions}
    end)
    |> Enum.each(fn {date, tps, nb_transactions} ->
      NetworkStatistics.register_tps(date, tps, nb_transactions)
      NetworkStatistics.increment_number_transactions(nb_transactions)
    end)
  end

  defp flatten_summaries(summaries) do
    Enum.reduce(
      summaries,
      %{
        end_of_node_synchronizations: [],
        transaction_summaries: [],
        nb_transactions_by_time: %{}
      },
      fn %BeaconSummary{
           summary_time: summary_time,
           transaction_summaries: transaction_summaries,
           end_of_node_synchronizations: end_of_node_synchronizations
         },
         acc ->
        acc
        |> Map.update!(:end_of_node_synchronizations, &(end_of_node_synchronizations ++ &1))
        |> Map.update!(:transaction_summaries, &(transaction_summaries ++ &1))
        |> update_in(
          [:nb_transactions_by_time, Access.key(summary_time |> Utils.truncate_datetime(), 0)],
          &(&1 + Enum.count(transaction_summaries))
        )
      end
    )
  end

  defp synchronize_transactions(transaction_summaries, node_patch) do
    transactions_to_sync =
      transaction_summaries
      |> Stream.uniq_by(& &1.address)
      |> Stream.reject(&TransactionChain.transaction_exists?(&1.address))
      |> Stream.filter(&TransactionHandler.download_transaction?/1)

    Logger.info("Need to synchronize #{Enum.count(transactions_to_sync)} transactions")

    transactions_to_sync
    |> TransactionHandler.sort_transactions_information()
    |> Enum.each(&TransactionHandler.download_transaction(&1, node_patch))
  end

  defp load_summaries_in_db(summaries) do
    Task.async_stream(
      summaries,
      fn summary = %BeaconSummary{subset: subset, summary_time: summary_time} ->
        storage_nodes =
          Election.beacon_storage_nodes(
            subset,
            summary_time,
            P2P.list_nodes(availability: :global)
          )

        if Utils.key_in_node_list?(storage_nodes, Crypto.node_public_key(0)) do
          DB.register_beacon_summary(summary)
        end
      end,
      ordered: false
    )
    |> Stream.run()
  end
end
