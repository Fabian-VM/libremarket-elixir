defmodule Libremarket.Infracciones.Middleware do

  def send_message(queue_name, message, state) do
    sent_message = Producer.send_message_with_clock(queue_name, message, state.vector_clock, :infracciones)
    state = %{ state | vector_clock: sent_message.vector_clock }
    state
  end

  def receive_message(raw_message, state) do
    rcv_message = Producer.read_message_with_clock(raw_message, state.vector_clock, :infracciones)
    state = %{ state | vector_clock: rcv_message.vector_clock }
    { rcv_message, state }
  end

end

defmodule Libremarket.Infracciones do

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def detectar_infracciones(compra_id, infraccion_detectada) do
    IO.puts("Compra N° #{compra_id}: #{if infraccion_detectada, do: "se ha detectado una", else: "no se ha detectado ninguna"} infracción\n")
    %{ compra_id: compra_id, infraccion_detectada: infraccion_detectada }
  end

  # UTILIDADES
  # -------------------------------------

  def verificar_infraccion() do
    Enum.random(1..100) <= 30
  end

  def find_by_compra_id(infracciones, compra_id) do
    Enum.find(infracciones, fn item -> item.compra_id == compra_id end)
  end

end

defmodule Libremarket.Infracciones.Server do
  @moduledoc """
  Módulo del servidor de infracciones
  """

  use GenServer
  use AMQP
  alias Libremarket.Infracciones
  alias Libremarket.Infracciones.Middleware

  @compras_queue_name "compras"
  @infracciones_queue_name "infracciones"
  @ventas_queue_name "ventas"


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...}
  #   infracciones: Infraccion[]
  #   vector_clock: VectorClock
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @infracciones_queue_name, durable: true)
    Basic.consume(amqp_channel, @infracciones_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      infracciones: [],
      vector_clock: Producer.VectorClock.new()
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

    {message, state} = Middleware.receive_message(raw_message, state)

    case message.content do
      {:detectar_infracciones, compra_id} ->
        estado_infraccion = Infracciones.verificar_infraccion()
        infraccion = Infracciones.detectar_infracciones(compra_id, estado_infraccion)
        state = %{ state | infracciones: [ infraccion | state.infracciones ] }
        state = Middleware.send_message(@compras_queue_name, {:informar_estado_infraccion, compra_id, estado_infraccion}, state)
        state = Middleware.send_message(@ventas_queue_name, {:informar_estado_infraccion, compra_id, estado_infraccion}, state)
        {:noreply, state}


      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end


end
