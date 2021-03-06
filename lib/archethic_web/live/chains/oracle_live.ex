defmodule ArchEthicWeb.OracleChainLive do
  @moduledoc false

  use ArchEthicWeb, :live_view

  alias ArchEthic.Crypto

  alias ArchEthic.PubSub

  alias ArchEthic.P2P
  alias ArchEthic.P2P.Node

  alias ArchEthic.OracleChain

  alias ArchEthic.TransactionChain
  alias ArchEthic.TransactionChain.Transaction
  alias ArchEthic.TransactionChain.Transaction.ValidationStamp
  alias ArchEthic.TransactionChain.TransactionData

  alias ArchEthicWeb.ExplorerView

  alias Phoenix.View

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.register_to_new_transaction_by_type(:oracle)
      PubSub.register_to_new_transaction_by_type(:oracle_summary)
    end

    last_tx =
      TransactionChain.list_transactions_by_type(:oracle,
        data: [:content],
        validation_stamp: [:timestamp]
      )
      |> Enum.at(0)

    {last_oracle_data, update_time} =
      case last_tx do
        nil ->
          {%{}, nil}

        %Transaction{
          data: %TransactionData{content: content},
          validation_stamp: %ValidationStamp{timestamp: timestamp}
        } ->
          {Jason.decode!(content), timestamp}
      end

    oracle_dates = get_oracle_dates() |> Enum.to_list()

    new_assign =
      socket
      |> assign(:last_oracle_data, last_oracle_data)
      |> assign(:update_time, update_time)
      |> assign(:dates, oracle_dates)
      |> assign(:current_date_page, 1)
      |> assign(:transactions, list_transactions_by_date(Enum.at(oracle_dates, 0)))

    {:ok, new_assign}
  end

  def render(assigns) do
    View.render(ExplorerView, "oracle_chain_index.html", assigns)
  end

  def handle_params(%{"page" => page}, _uri, socket = %{assigns: %{dates: dates}}) do
    case Integer.parse(page) do
      {number, ""} when number > 0 ->
        transactions =
          dates
          |> Enum.at(number - 1)
          |> list_transactions_by_date()

        new_assign =
          socket
          |> assign(:current_date_page, number)
          |> assign(:transactions, transactions)

        {:noreply, new_assign}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_params(%{}, _, socket) do
    {:noreply, socket}
  end

  def handle_event("goto", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, %{"page" => page}))}
  end

  def handle_info(
        {:new_transaction, address, :oracle},
        socket
      ) do
    {:ok,
     %Transaction{
       data: %TransactionData{content: content},
       validation_stamp: %ValidationStamp{timestamp: timestamp}
     }} =
      TransactionChain.get_transaction(address, data: [:content], validation_stamp: [:timestamp])

    last_oracle_data = Jason.decode!(content)

    new_assign =
      socket
      |> assign(:last_oracle_data, last_oracle_data)
      |> assign(:update_time, timestamp)

    {:noreply, new_assign}
  end

  def handle_info(
        {:new_transaction, _address, :oracle_summary},
        socket = %{assigns: %{current_date_page: page}}
      ) do
    dates = get_oracle_dates()

    transactions =
      dates
      |> Enum.at(page - 1)
      |> list_transactions_by_date()

    new_assign =
      socket
      |> assign(:dates, dates)
      |> assign(:transactions, transactions)

    {:noreply, new_assign}
  end

  defp get_oracle_dates do
    %Node{enrollment_date: enrollment_date} =
      P2P.list_nodes() |> Enum.sort_by(& &1.enrollment_date, {:asc, DateTime}) |> Enum.at(0)

    enrollment_date
    |> OracleChain.summary_dates()
    |> Enum.sort({:desc, DateTime})
  end

  defp list_transactions_by_date(date = %DateTime{}) do
    date
    |> Crypto.derive_oracle_address(0)
    |> TransactionChain.get_last_address()
    |> TransactionChain.get([:address, :type, validation_stamp: [:timestamp]])
  end

  defp list_transactions_by_date(nil), do: []
end
