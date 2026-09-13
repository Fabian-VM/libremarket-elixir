defmodule Libremarket.Infracciones do

  def detectar_infraccion() do
    Enum.random(1..100) <= 30
  end

  def registrar_infraccion(compra_id, infraccion_detectada) do
    IO.puts("Compra N° #{compra_id}: #{if infraccion_detectada, do: "se ha detectado una", else: "no se ha detectado ninguna"} infracción")
    %{ compra_id: compra_id, infraccion_detectada: infraccion_detectada }
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
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @infracciones_queue_name, durable: true)
    Basic.consume(amqp_channel, @infracciones_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      infracciones: []
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
      {:detectar_infracciones, compra_id} ->
        estado_infraccion = Libremarket.Infracciones.detectar_infraccion()
        infraccion = Libremarket.Infracciones.registrar_infraccion(compra_id, estado_infraccion)
        new_state = %{ state | infracciones: [ infraccion | state.infracciones ] }
        Producer.send_message(@compras_queue_name, {:informar_estado_infraccion, compra_id, estado_infraccion})
        Producer.send_message(@ventas_queue_name, {:informar_estado_infraccion, compra_id, estado_infraccion})
        {:noreply, new_state}


      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}")
        {:noreply, state}

    end

  end


end
