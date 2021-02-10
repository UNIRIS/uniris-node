defmodule UnirisWeb.ExplorerIndexLive do
  @moduledoc false

  use UnirisWeb, :live_view

  alias Phoenix.View

  alias Uniris.P2P
  alias Uniris.PubSub
  alias Uniris.SelfRepair

  alias UnirisWeb.ExplorerView

  def mount(_params, _session, socket) do
    nb_nodes = P2P.list_nodes(availability: :global) |> length()
    tps = SelfRepair.get_latest_tps()
    nb_transactions = SelfRepair.get_nb_transactions()

    if connected?(socket) do
      PubSub.register_to_new_tps()
      PubSub.register_to_new_transaction_number()
    end

    new_socket =
      socket
      |> assign(:nb_nodes, nb_nodes)
      |> assign(:tps, tps)
      |> assign(:nb_transactions, nb_transactions)

    {:ok, new_socket}
  end

  def render(assigns) do
    View.render(ExplorerView, "index.html", assigns)
  end

  def handle_info({:new_tps, tps}, socket) do
    {:noreply, assign(socket, :tps, tps)}
  end

  def handle_info({:new_transaction_number, nb}, socket) do
    {:noreply, assign(socket, :nb_transactions, nb)}
  end

  def handle_event("search", %{"address" => address}, socket) do
    {:noreply, redirect(socket, to: "/explorer/transaction/#{address}")}
  end
end
