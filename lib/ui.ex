defmodule Libremarket.Ui do
  @moduledoc """
  Módulo de lógica de la interfaz
  """

  def crear_solicitud(compra_id, producto_id, forma_entrega, medio_pago, confirma_compra) do
    IO.puts("Compra N° #{compra_id}: solicitud de compra creada")
    %{
      compra_id: compra_id,
      producto_id: producto_id,
      forma_entrega: forma_entrega,
      medio_pago: medio_pago,
      confirma_compra: confirma_compra
    }
  end

  def informar_stock_insuficiente(compra_id) do
    IO.puts("Compra N° #{compra_id}: se ha cancelado su compra, debido a que el stock es insuficiente")
  end

  def informar_infraccion(compra_id) do
    IO.puts("Compra N° #{compra_id}: se ha cancelado su compra, debido a que se ha detectado una infracción")
  end

  def informar_pago_rechazado(compra_id) do
    IO.puts("Compra N° #{compra_id}: se ha cancelado su compra, debido a que se ha rechazado el pago")
  end

  def informar_compra_finalizada(compra_id) do
    IO.puts("Compra N° #{compra_id}: se ha finalizado su compra con éxito. Hasta nunca!")
  end

  # Encontrar una solicitud en una lista de solicitudes
  def find_solicitud_by_id(solicitudes, compra_id) do
    Enum.find(solicitudes, fn item -> item.compra_id == compra_id end)
  end

end



defmodule Libremarket.Ui.Server do
  @moduledoc """
  Módulo del servidor de interfaz (API de uso público)
  """

  use GenServer
  use AMQP

  @ui_queue_name "ui"
  @compras_queue_name "compras"


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...}
  #   secuencia_id: numero
  #   solicitudes: Solicitud[]
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @ui_queue_name, durable: true)
    Basic.consume(amqp_channel, @ui_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      secuencia_id: 0,
      solicitudes: []
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
      {:simular_compra, producto_id, forma_entrega, medio_pago, confirma_compra} ->
        compra_id = state.secuencia_id + 1
        IO.puts("Un usuario inicia la compra N° #{compra_id}")
        solicitud = Libremarket.Ui.crear_solicitud(compra_id, producto_id, forma_entrega, medio_pago, confirma_compra)
        new_state = %{ state | secuencia_id: compra_id, solicitudes: [ solicitud | state.solicitudes ]}
        Producer.send_message(@compras_queue_name, {:seleccionar_producto, compra_id, producto_id})
        {:noreply, new_state}

      {:seleccionar_forma_entrega, compra_id} ->
        solicitud = Libremarket.Ui.find_solicitud_by_id(state.solicitudes, compra_id)
        Producer.send_message(
          @compras_queue_name,
          {:seleccionar_forma_entrega, compra_id, solicitud.forma_entrega}
        )
        {:noreply, state}

      {:seleccionar_medio_pago, compra_id} ->
        solicitud = Libremarket.Ui.find_solicitud_by_id(state.solicitudes, compra_id)
        Producer.send_message(
          @compras_queue_name,
          {:seleccionar_medio_pago, compra_id, solicitud.medio_pago}
        )
        {:noreply, state}

      {:confirmar_compra, compra_id} ->
        solicitud = Libremarket.Ui.find_solicitud_by_id(state.solicitudes, compra_id)
        Producer.send_message(
          @compras_queue_name,
          {:confirmar_compra, compra_id, solicitud.confirma_compra}
        )
        {:noreply, state}

      {:informar_stock_insuficiente, compra_id} ->
        Libremarket.Ui.informar_stock_insuficiente(compra_id)
        {:noreply, state}

      {:informar_infraccion, compra_id} ->
        Libremarket.Ui.informar_infraccion(compra_id)
        {:noreply, state}

      {:informar_pago_rechazado, compra_id} ->
        Libremarket.Ui.informar_pago_rechazado(compra_id)
        {:noreply, state}

      {:informar_compra_finalizada, compra_id} ->
        Libremarket.Ui.informar_compra_finalizada(compra_id)
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
