defmodule Libremarket.Pagos.Middleware do

  def send_message(queue_name, message, state) do
    sent_message = Producer.send_message_with_clock(queue_name, message, state.vector_clock, :pagos)
    state = %{ state | vector_clock: sent_message.vector_clock }
    state
  end

  def receive_message(raw_message, state) do
    rcv_message = Producer.read_message_with_clock(raw_message, state.vector_clock, :pagos)
    state = %{ state | vector_clock: rcv_message.vector_clock }
    { rcv_message, state }
  end

end


defmodule Libremarket.Pagos do
  @moduledoc """
  Módulo de lógica de pagos
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def autorizar_pago(compra_id) do
    pago_autorizado = Enum.random(1..100) <= 70
    IO.puts("Compra N° #{compra_id}: pago #{if pago_autorizado, do: "autorizado", else: "no autorizado"}\n")
    pago_autorizado
  end

end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Módulo del servidor de pagos
  """

  use GenServer
  use AMQP
  alias Libremarket.Pagos
  alias Libremarket.Pagos.Middleware

  @compras_queue_name "compras"
  @ventas_queue_name "ventas"
  @pagos_queue_name "pagos"


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...},
  #   vector_clock: VectorClock
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @pagos_queue_name, durable: true)
    Basic.consume(amqp_channel, @pagos_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
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
      {:autorizar_pago, compra_id} ->
        estado_pago = Pagos.autorizar_pago(compra_id)
        state = Middleware.send_message(@compras_queue_name, {:informar_estado_pago, compra_id, estado_pago}, state)
        state = Middleware.send_message(@ventas_queue_name, {:informar_estado_pago, compra_id, estado_pago}, state)
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
