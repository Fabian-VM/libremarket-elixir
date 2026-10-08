
defmodule Libremarket.Pagos do
  @moduledoc """
  Módulo de lógica de pagos
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def autorizar_pago(compra_id) do
    pago_autorizado = Enum.random(1..100) <= Constantes.prob_pago_autorizado()
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


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...},
  #   vector_component: VectorClock.component
  #   vector_clock: VectorClock
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, Constantes.pagos_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.pagos_queue(), nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      vector_component: :pagos,
      vector_clock: Middleware.VectorClock.new()
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
      {:autorizar_pago, compra_id} ->
        estado_pago = Pagos.autorizar_pago(compra_id)
        state = Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_pago, compra_id, estado_pago}, state)
        state = Middleware.send_message_server(Constantes.ventas_queue(), {:informar_estado_pago, compra_id, estado_pago}, state)
        {:noreply, state}

      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}

      {:show_clock} ->
        Middleware.VectorClock.print(state.vector_clock)
        {:noreply, state}

      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end



end
