
defmodule Libremarket.Envios do
  @moduledoc """
  Módulo de lógica de envios
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def calcular_costo(compra_id, forma_entrega) do
    costo_envio = if forma_entrega == :correo, do: 50, else: 0
    IO.puts("Compra N° #{compra_id}: costo de envío de $#{costo_envio} rupias\n")
    costo_envio
  end

  def agendar_envio(compra_id) do
    fecha = Date.utc_today()
    IO.puts("Compra N° #{compra_id}: envio agendado para el dia #{fecha}\n")
    fecha
  end

end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Módulo del servidor de envios
  """

  use GenServer
  use AMQP
  alias Libremarket.Envios


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
    Queue.declare(amqp_channel, Constantes.envios_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.envios_queue(), nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      vector_component: :envios,
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
      {:calcular_costo, compra_id, forma_entrega} ->
        costo_envio = Envios.calcular_costo(compra_id, forma_entrega)
        state = Middleware.send_message_server(Constantes.compras_queue(), {:informar_costo_envio, compra_id, costo_envio}, state)
        {:noreply, state}

      {:agendar_envio, compra_id} ->
        fecha_envio = Envios.agendar_envio(compra_id)
        state = Middleware.send_message_server(Constantes.ventas_queue(), {:agendar_envio, compra_id, fecha_envio}, state)
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
