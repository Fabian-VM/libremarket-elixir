defmodule Libremarket.Infracciones do

  def detectar_infraccion(compra_id) do
    infraccion_detectada = Enum.random(1..100) <= 30
    IO.puts("[INFRACCIONES]\t| Compra N° #{compra_id}: #{if infraccion_detectada, do: "se ha detectado una", else: "no se ha detectado ninguna"} infracción")
    %{ compra_id: compra_id, infraccion_detectada: infraccion_detectada }
  end

end

defmodule Libremarket.Infracciones.Server do
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

  def detectar_infraccion(pid \\ __MODULE__, compra_id) do
    GenServer.call(pid, {:detectar_infraccion, compra_id})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_infracciones)
  end

  def find_by_compra_id(state, compra_id) do
    Enum.find(state.infracciones, fn item -> item.compra_id == compra_id end)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_state) do
    initial_state = %{ infracciones: [] }
    {:ok, initial_state}
  end

  # state {
  #   infracciones: [
  #     { compra_id: numero, infraccion_detectada: booleano }
  #   ]
  # }

  @impl true
  def handle_call({:detectar_infraccion, compra_id}, _from, state) do
    infraccion = Libremarket.Infracciones.detectar_infraccion(compra_id)
    new_state = %{ state | infracciones: [infraccion | state.infracciones] }
    {:reply, infraccion.infraccion_detectada, new_state}
  end

  @impl true
  def handle_call(:listar_infracciones, _from, state) do
    {:reply, state.infracciones, state}
  end

end
