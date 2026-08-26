defmodule Libremarket.Ventas do

  def hay_stock_suficiente(stock_productos, producto_id) do
    stock = Map.get(stock_productos, producto_id)
    stock_suficiente = stock - 1 >= 0
    if (stock_suficiente) do
      IO.puts("[VENTAS]\t| Producto ##{producto_id}: #{stock} unidades disponibles")
    else
      IO.puts("[VENTAS]\t| Producto ##{producto_id}: insuficiente stock del producto ")
    end
    stock_suficiente
  end

  def reservar_producto(stock_productos, producto_id) do

    Map.update(stock_productos, producto_id, 0, fn stock ->
      IO.puts("[VENTAS]\t| Producto ##{producto_id}: unidad reservada (#{stock - 1} unidades restantes)")
      stock - 1
    end)

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

  def reservar_producto(producto_id) do
    GenServer.call(__MODULE__, {:reservar_producto, producto_id})
  end

  def reservar_producto(pid, producto_id) do
    GenServer.call(pid, {:reservar_producto, producto_id})
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
    {:ok, initial_state}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call({:reservar_producto, producto_id}, _from, state) do
    if (Libremarket.Ventas.hay_stock_suficiente(state, producto_id)) do
      stock_productos_actualizados = Libremarket.Ventas.reservar_producto(state, producto_id)
      {:reply, :true, stock_productos_actualizados}
    else
      {:reply, :false, state}
    end
  end

end
