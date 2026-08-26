defmodule Libremarket.Pagos do

  def autorizar_pago() do
    if (Enum.random(1..100) <= 70) do
      :pago_autorizado
    else
      :pago_rechazado
    end

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

  def autorizar_pago(pid \\ __MODULE__) do
    GenServer.call(pid, :autorizar_pago)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :autorizar_pago
  """
  @impl true
  def handle_call(:autorizar_pago, _from, state) do
    result = Libremarket.Pagos.autorizar_pago()
    {:reply, result, state}
  end

end
