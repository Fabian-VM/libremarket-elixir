defmodule Libremarket.Ventas do

  def stock_suficiente(productos, compra_id, producto_id) do
    stock = Map.get(productos, producto_id)
    stock_suficiente = stock - 1 >= 0
    if (stock_suficiente) do
      IO.puts("[VENTAS]\t| Compra N° #{compra_id}: es posible reservar una unidad del producto ##{producto_id} (#{stock} unidades disponibles)")
    else
      IO.puts("[VENTAS]\t| Compra N° #{compra_id}: insuficiente stock del producto ##{producto_id}")
    end
    stock_suficiente
  end

  def reservar_producto(productos, compra_id, producto_id) do
    Map.update(productos, producto_id, 0, fn stock ->
      IO.puts("[VENTAS]\t| Compra N° #{compra_id}: unidad reservada del producto ##{producto_id} (#{stock - 1} unidades restantes)")
      stock - 1
    end)
  end

  def liberar_producto(productos, compra_id, producto_id) do
    Map.update(productos, producto_id, 0, fn stock ->
      IO.puts("[VENTAS]\t| Compra N° #{compra_id}: unidad liberada del producto ##{producto_id} (#{stock + 1} unidades restantes)")
      stock + 1
    end)
  end

  def enviar_producto(compra_id, producto_id) do
    IO.puts("[VENTAS]\t| Compra N° #{compra_id}: producto #{producto_id} enviado")
  end

end

defmodule Libremarket.Ventas.Server do
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

  def reservar_producto(server \\ __MODULE__, compra_id, producto_id) do
    GenServer.call(server, {:reservar_producto, compra_id, producto_id})
  end

  def liberar_producto(server \\ __MODULE__, compra_id, producto_id) do
    GenServer.call(server, {:liberar_producto, compra_id, producto_id})
  end

  def enviar_producto(server \\ __MODULE__, compra_id, producto_id) do
    GenServer.call(server, {:enviar_producto, compra_id, producto_id})
  end

  def listar_productos(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_productos)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    min_stock = 1
    max_stock = 10
    initial_state = %{
      productos: %{
        1 => Enum.random(min_stock .. max_stock),
        2 => Enum.random(min_stock .. max_stock),
        3 => Enum.random(min_stock .. max_stock),
        4 => Enum.random(min_stock .. max_stock),
        5 => Enum.random(min_stock .. max_stock),
        6 => Enum.random(min_stock .. max_stock),
        7 => Enum.random(min_stock .. max_stock),
        8 => Enum.random(min_stock .. max_stock),
        9 => Enum.random(min_stock .. max_stock),
        10 => Enum.random(min_stock .. max_stock)
      }
    }
    {:ok, initial_state}
  end

  # state {
  #   productos: [
  #     { numero => cantidad }
  #   ]
  # }

  @impl true
  def handle_call({:reservar_producto, compra_id, producto_id}, _from, state) do
    if (Libremarket.Ventas.stock_suficiente(state.productos, compra_id, producto_id)) do
      productos_actualizados = Libremarket.Ventas.reservar_producto(state.productos, compra_id, producto_id)
      new_state = %{ state | productos: productos_actualizados}
      {:reply, :true, new_state}
    else
      {:reply, :false, state}
    end
  end

  @impl true
  def handle_call({:liberar_producto, compra_id, producto_id}, _from, state) do
    productos_actualizados = Libremarket.Ventas.liberar_producto(state.productos, compra_id, producto_id)
    new_state = %{ state | productos: productos_actualizados}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:enviar_producto, compra_id, producto_id}, _from, state) do
    Libremarket.Ventas.enviar_producto(compra_id, producto_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:listar_productos, _from, state) do
    {:reply, state.productos, state}
  end

end
