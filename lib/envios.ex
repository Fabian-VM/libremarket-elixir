defmodule Libremarket.Envios do

  def calcular_costo(compra_id, forma_entrega) do
    costo_envio = if forma_entrega == :correo, do: 10, else: 0
    IO.puts("[ENVIOS]\t| Compra N° #{compra_id}: costo de envío de $#{costo_envio}")
    costo_envio
  end

  def agendar_envio(compra_id) do
    fecha = Date.utc_today()
    IO.puts("[ENVIOS]\t| Compra N° #{compra_id}: envio agendado para el dia #{fecha}")
    fecha
  end

end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Compras
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def calcular_costo(pid \\ __MODULE__, compra_id, forma_entrega) do
    GenServer.call(pid, {:calcular_costo, compra_id, forma_entrega})
  end

  def agendar_envio(pid \\ __MODULE__, compra_id) do
    GenServer.call(pid, {:agendar_envio, compra_id})
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
  def handle_call({:calcular_costo, compra_id, forma_entrega}, _from, state) do
    costo_envio = Libremarket.Envios.calcular_costo(compra_id, forma_entrega)
    {:reply, costo_envio, state}
  end

  @impl true
  def handle_call({:agendar_envio, compra_id}, _from, state) do
    fecha = Libremarket.Envios.agendar_envio(compra_id)
    {:reply, fecha, state}
  end

end
