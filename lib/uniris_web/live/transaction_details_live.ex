defmodule UnirisWeb.TransactionDetailsLive do
  @moduledoc false
  use UnirisWeb, :live_view

  alias Phoenix.View

  alias Uniris.PubSub

  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.TransactionData

  alias UnirisWeb.ExplorerView

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, %{
       exists: false,
       previous_address: nil,
       transaction: nil,
       hide_content: true,
       tab_panel: "tx",
       data_section: "code",
       operation_section: "transaction_movements"
     })}
  end

  def handle_params(opts = %{"address" => address}, _uri, socket) do
    case Base.decode16(address, case: :mixed) do
      {:ok, addr} ->
        case get_transaction(addr, opts) do
          {:ok, tx} ->
            {:noreply, handle_transaction(socket, tx)}

          _ ->
            PubSub.register_to_new_transaction_by_address(addr)
            {:noreply, handle_not_existing_transaction(socket, addr)}
        end

      _ ->
        {:noreply, handle_invalid_address(socket, address)}
    end
  end

  def handle_event("switch_tab", %{"tab_panel" => tab_panel}, socket) do
    {:noreply, assign(socket, :tab_panel, tab_panel)}
  end

  def handle_event("switch_data", %{"data_section" => data_section}, socket) do
    {:noreply, assign(socket, :data_section, data_section)}
  end

  def handle_event(
        "switch_ledger_operations",
        %{"operation_section" => operation_section},
        socket
      ) do
    {:noreply, assign(socket, :operation_section, operation_section)}
  end

  def handle_event("hide_content", _value, socket = %{assigns: %{hide_content: false}}) do
    {:noreply, assign(socket, :hide_content, true)}
  end

  def handle_event("show_content", _value, socket = %{assigns: %{hide_content: true}}) do
    {:noreply, assign(socket, :hide_content, false)}
  end

  def handle_info({:new_transaction, address}, socket) do
    {:ok, tx} = get_transaction(address, %{})

    new_socket =
      socket
      |> assign(:ko?, false)
      |> handle_transaction(tx)

    {:noreply, new_socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def render(assigns = %{ko?: true}) do
    View.render(ExplorerView, "ko_transaction.html", assigns)
  end

  def render(assigns) do
    View.render(ExplorerView, "transaction_details.html", assigns)
  end

  defp get_transaction(address, %{"address" => "true"}) do
    Uniris.get_last_transaction(address)
  end

  defp get_transaction(address, _opts = %{}) do
    Uniris.search_transaction(address)
  end

  defp handle_transaction(
         socket,
         tx = %Transaction{address: address, data: %TransactionData{content: content}}
       ) do
    balance = Uniris.get_balance(address)
    previous_address = Transaction.previous_address(tx)

    inputs = Uniris.get_transaction_inputs(address)
    ledger_inputs = Enum.reject(inputs, &(&1.type == :call))
    contract_inputs = Enum.filter(inputs, &(&1.type == :call))

    socket
    |> assign(:transaction, tx)
    |> assign(:previous_address, previous_address)
    |> assign(:balance, balance)
    |> assign(:inputs, ledger_inputs)
    |> assign(:calls, contract_inputs)
    |> assign(:address, address)
    |> assign(:hide_content, byte_size(content) > 1000)
  end

  def handle_not_existing_transaction(socket, address) do
    inputs = Uniris.get_transaction_inputs(address)
    ledger_inputs = Enum.reject(inputs, &(&1.type == :call))
    contract_inputs = Enum.filter(inputs, &(&1.type == :call))

    socket
    |> assign(:address, address)
    |> assign(:inputs, ledger_inputs)
    |> assign(:calls, contract_inputs)
    |> assign(:error, :not_exists)
  end

  def handle_invalid_address(socket, address) do
    socket
    |> assign(:address, address)
    |> assign(:inputs, [])
    |> assign(:calls, [])
    |> assign(:error, :invalid_address)
  end
end
