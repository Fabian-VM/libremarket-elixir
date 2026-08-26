defmodule Libremarket.Compras do

  def comprar(compra_id, producto_id, forma_entrega, medio_pago) do
    _compra = Libremarket.Compras.seleccionar_producto(compra_id, producto_id)

    # Detectar infracción
    Libremarket.Infracciones.Server.detectar_infraccion(compra_id)

    # Reservar producto
    Libremarket.Ventas.Server.reservar_producto(producto_id)

    # Seleccionar forma de entrega
    Libremarket.Compras.seleccionar_forma_entrega(compra_id, forma_entrega)

    # Calcular costo de envio
    costo_envio = if forma_entrega == :retira, do: 0, else: 10 # calcular costo
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: costo de envío de $#{costo_envio}")

    # Seleccionar medio de pago
    Libremarket.Compras.seleccionar_medio_pago(compra_id, medio_pago)

    # Confirmar compra
    Libremarket.Compras.confirmar_compra(compra_id)

  end

  def seleccionar_producto(compra_id, producto_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: producto ##{producto_id} seleccionado")
    %{
      compra_id: compra_id,
      producto_id: producto_id,
      forma_entrega: nil,
      medio_pago: nil,
      costo_envio: nil
    }
  end

  def seleccionar_forma_entrega(compra_id, forma_entrega) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: forma de entrega '#{forma_entrega}' seleccionada")
  end

  def seleccionar_medio_pago(compra_id, medio_pago) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: medio de pago '#{medio_pago}' seleccionado")
  end

  def confirmar_compra(compra_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: confirmada")
  end


end

defmodule Libremarket.Compras.Server do
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


  def comprar(producto_id, forma_entrega, medio_pago) do
    GenServer.call(__MODULE__, {:comprar, producto_id, forma_entrega, medio_pago})
  end

  def comprar(pid, producto_id, forma_entrega, medio_pago) do
    GenServer.call(pid, {:comprar, producto_id, forma_entrega, medio_pago})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    initial_state = %{secuencia_id: 0, compras: []}
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:comprar, producto_id, forma_entrega, medio_pago}, _from, state) do
    compra_id = state.secuencia_id + 1
    compra = Libremarket.Compras.comprar(compra_id, producto_id, forma_entrega, medio_pago)
    new_state = %{
      state |
      secuencia_id: compra_id,
      compras: state.compras ++ [compra]
    }
    {:reply, compra_id, new_state}
  end

end
