defmodule Libremarket.Pagos do
  @moduledoc """
  Módulo de lógica de pagos
  """

  def autorizar_pago(compra_id) do
    pago_autorizado = Enum.random(1..100) <= 70
    IO.puts("Compra N° #{compra_id}: pago #{if pago_autorizado, do: "autorizado", else: "no autorizado"}")
    pago_autorizado
  end

end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Módulo del servidor de pagos
  """

  use GenServer
  use AMQP

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
  #   amqp_channel: {...}
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @pagos_queue_name, durable: true)
    Basic.consume(amqp_channel, @pagos_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
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
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case :erlang.binary_to_term(payload) do
      {:autorizar_pago, compra_id} ->
        estado_pago = Libremarket.Pagos.autorizar_pago(compra_id)
        Producer.send_message(@compras_queue_name, {:informar_estado_pago, compra_id, estado_pago})
        Producer.send_message(@ventas_queue_name, {:informar_estado_pago, compra_id, estado_pago})
        {:noreply, state}

      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}

      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}")
        {:noreply, state}

    end

  end



end
