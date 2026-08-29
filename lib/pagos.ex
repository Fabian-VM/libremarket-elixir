defmodule Libremarket.Pagos do

  def autorizar_pago(compra_id) do
    pago_autorizado = Enum.random(1..100) <= 70
    IO.puts("[PAGOS]\t\t| Compra N° #{compra_id}: pago #{if pago_autorizado, do: "autorizado", else: "no autorizado"}")
    pago_autorizado
  end

end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Pagos
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de pagos
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def autorizar_pago(pid \\ __MODULE__, compra_id) do
    GenServer.call(pid, {:autorizar_pago, compra_id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:autorizar_pago, compra_id}, _from, state) do
    result = Libremarket.Pagos.autorizar_pago(compra_id)
    {:reply, result, state}
  end

end
