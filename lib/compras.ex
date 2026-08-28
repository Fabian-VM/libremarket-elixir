defmodule Libremarket.Compras do

  def seleccionar_producto(compra_id, producto_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: producto ##{producto_id} seleccionado")
      %{
        compra_id: compra_id,
        producto_id: producto_id,
        forma_entrega: nil,
        medio_pago: nil,
        costo_envio: nil,
        confirmada_por_usuario: nil
      }

  end

  def seleccionar_forma_entrega(compra, forma_entrega) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: forma de entrega '#{forma_entrega}' seleccionada")
    %{
      compra |
      forma_entrega: forma_entrega
    }
  end

  def seleccionar_medio_pago(compra, medio_pago) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: medio de pago '#{medio_pago}' seleccionado")
    %{
      compra |
      medio_pago: medio_pago
    }
  end

  def confirmar_compra(compra) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: confirmada por el usuario")
    %{
      compra |
      confirmada_por_usuario: true
    }
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

  def seleccionar_producto(producto_id) do
    GenServer.call(__MODULE__, {:seleccionar_producto, producto_id})
  end

  def seleccionar_producto(pid, producto_id) do
    GenServer.call(pid, {:seleccionar_producto, producto_id})
  end

  def seleccionar_forma_entrega(compra_id, forma_entrega) do
    GenServer.call(__MODULE__, {:seleccionar_forma_entrega, compra_id, forma_entrega})
  end

  def seleccionar_forma_entrega(pid, compra_id, forma_entrega) do
    GenServer.call(pid, {:seleccionar_forma_entrega, compra_id, forma_entrega})
  end

  def seleccionar_medio_pago(compra_id, medio_pago) do
    GenServer.call(__MODULE__, {:seleccionar_medio_pago, compra_id, medio_pago})
  end

  def seleccionar_medio_pago(pid, compra_id, medio_pago) do
    GenServer.call(pid, {:seleccionar_medio_pago, compra_id, medio_pago})
  end

  def confirmar_compra(compra_id) do
    GenServer.call(__MODULE__, {:confirmar_compra, compra_id})
  end

  def confirmar_compra(pid, compra_id) do
    GenServer.call(pid, {:confirmar_compra, compra_id})
  end

  def find_compra_by_id(state, compra_id) do
    Enum.find(state.compras, fn item -> item.compra_id == compra_id end)
  end

  def update_compra(state, new_compra) do
    # Recrear la lista de compras pero con la compra actualizada
    new_compras = Enum.map(state.compras, fn item ->
      if item.compra_id == new_compra.compra_id, do: new_compra, else: item
    end)

    # Crear el estado actualizado
    %{
      state |
      compras: new_compras
    }
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

  # state {
  #   secuencia_id: numero
  #   compras: [
  #     { compra_id: numero, producto_id: numero , ...}
  #   ]
  # }

  @impl true
  def handle_call({:seleccionar_producto, producto_id}, _from, state) do
    compra_id = state.secuencia_id + 1
    compra = Libremarket.Compras.seleccionar_producto(compra_id, producto_id)
    new_state = %{
      state |
      secuencia_id: compra_id,
      compras: [compra | state.compras]
    }
    {:reply, compra_id, new_state}
  end

  @impl true
  def handle_call({:seleccionar_forma_entrega, compra_id, forma_entrega}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.seleccionar_forma_entrega(compra, forma_entrega)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}

    # Habria que incluir un caso donde la compra no exista
  end

  @impl true
  def handle_call({:seleccionar_medio_pago, compra_id, medio_pago}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.seleccionar_medio_pago(compra, medio_pago)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  def handle_call({:confirmar_compra, compra_id}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    result = Libremarket.Compras.confirmar_compra(compra)
    {:reply, result, state}
  end

end
