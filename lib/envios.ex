defmodule Libremarket.Envios do
  @moduledoc """
  Módulo de lógica de envios
  """

  def calcular_costo(compra_id, forma_entrega) do
    costo_envio = if forma_entrega == :correo, do: 50, else: 0
    IO.puts("Compra N° #{compra_id}: costo de envío de $#{costo_envio} rupias")
    costo_envio
  end

  def agendar_envio(compra_id) do
    fecha = Date.utc_today()
    IO.puts("Compra N° #{compra_id}: envio agendado para el dia #{fecha}")
    fecha
  end

end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Módulo del servidor de envios
  """

  use GenServer
  use AMQP

  @compras_queue_name "compras"
  @ventas_queue_name "ventas"
  @envios_queue_name "envios"


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
    Queue.declare(amqp_channel, @envios_queue_name, durable: true)
    Basic.consume(amqp_channel, @envios_queue_name, nil, no_ack: true)

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
      {:calcular_costo, compra_id, forma_entrega} ->
        costo_envio = Libremarket.Envios.calcular_costo(compra_id, forma_entrega)
        Producer.send_message(@compras_queue_name, {:registrar_costo_envio, compra_id, costo_envio})
        {:noreply, state}

      {:agendar_envio, compra_id} ->
        fecha_envio = Libremarket.Envios.agendar_envio(compra_id)
        Producer.send_message(@ventas_queue_name, {:agendar_envio, compra_id, fecha_envio})
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
