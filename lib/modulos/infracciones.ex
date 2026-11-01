defmodule Libremarket.Infracciones do
  @moduledoc """
  Módulo de lógica de infracciones
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def detectar_infracciones(compra_id, infraccion_detectada) do
    IO.puts("Compra N° #{compra_id}: #{if infraccion_detectada, do: "se ha detectado una", else: "no se ha detectado ninguna"} infracción\n")
    Repositorio.Infracciones.registrar_infraccion(compra_id, infraccion_detectada)
  end

  # UTILIDADES
  # -------------------------------------

  def verificar_infraccion() do
    Enum.random(1..100) <= Constantes.prob_infraccion()
  end

  def find_by_compra_id(compra_id) do
    Repositorio.Infracciones.get_infraccion(compra_id)
  end

end

defmodule Libremarket.Infracciones.Server do
  @moduledoc """
  Módulo del servidor de infracciones
  """

  use GenServer
  use AMQP
  alias Libremarket.Infracciones


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...}
  #   vector_component: VectorClock.component
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, Constantes.infracciones_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.infracciones_queue(), nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      vector_component: :infracciones
    }

    {:ok, initial_state}
  end

  # Necesario para recibir una confirmación del broker al registrarse como consumidor
  # (Si no está este handler, va a suceder un error de invocación a una función que no existe)
  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Recepción de mensajes
  @impl true
  def handle_info({:basic_deliver, raw_message, _meta}, state) do

    {message, state} = Middleware.read_message_server(raw_message, state)

    case message.content do
      {:detectar_infracciones, compra_id} ->
        estado_infraccion = Infracciones.verificar_infraccion()
        _infraccion = Infracciones.detectar_infracciones(compra_id, estado_infraccion)
        state = Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_infraccion, compra_id, estado_infraccion}, state)
        state = Middleware.send_message_server(Constantes.ventas_queue(), {:informar_estado_infraccion, compra_id, estado_infraccion}, state)
        {:noreply, state}


      {:show_state} ->
        IO.inspect(Repositorio.Infracciones.all_infracciones(), label: "Infracciones en DB")
        {:noreply, state}

      {:show_clock} ->
        clock = Repositorio.VectorClocks.get_clock(state.vector_component)
        Middleware.VectorClock.print(clock)
        {:noreply, state}

      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end


end
