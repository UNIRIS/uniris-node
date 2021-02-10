defmodule Uniris.Networking.PortForwarding do
  @moduledoc """
  Manage the port forwarding
  """

  require Logger

  @doc """
  Try to open a port using the port publication from UPnP or PmP otherwise fallback to either random or manual router configuration
  """
  @spec try_open_port(port_to_open :: :inet.port_number(), force? :: boolean()) ::
          :inet.port_number()
  def try_open_port(port, force?) when is_integer(port) and port >= 0 and is_boolean(force?) do
    case do_try_open_port(port) do
      {:ok, port} ->
        port

      {:error, _} ->
        fallback(port, force?)
    end
  end

  defp do_try_open_port(port), do: assign_port([:natupnp_v1, :natupnp_v2, :natpmp], port)

  defp assign_port([], _), do: {:error, :port_unassigned}

  defp assign_port([protocol_module | protocol_modules], port) do
    with {:ok, router_ip} <- protocol_module.discover(),
         {:ok, _, internal_port, _, _} <-
           protocol_module.add_port_mapping(router_ip, :tcp, port, port, 0) do
      {:ok, internal_port}
    else
      {:error, {:http_error, _code, _reason}} -> assign_port(protocol_modules, port)
      {:error, :einval} -> assign_port(protocol_modules, port)
      {:error, :no_nat} -> assign_port(protocol_modules, port)
      {:error, :timeout} -> assign_port(protocol_modules, port)
    end
  end

  defp fallback(port, _force? = true) do
    case do_try_open_port(0) do
      {:ok, port} ->
        port

      {:error, _} ->
        Logger.error("Cannot publish the a random port #{port}")

        Logger.info(
          "Port from configuration is used but requires a manuel port forwarding setting on the router"
        )

        port
    end
  end

  defp fallback(port, _force? = false) do
    Logger.error("Cannot publish the port #{port}")

    Logger.info(
      "Port from configuration is used but requires a manuel port forwarding setting on the router"
    )

    port
  end
end
