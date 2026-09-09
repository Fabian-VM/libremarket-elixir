defmodule GenServerConsumer do

  use AMQP

  @queue_name "compras"

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_state) do
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declarar la cola de mensajes
    Queue.declare(channel, @queue_name, durable: true)

    # Configurar el consumidor
    Basic.consume(channel, @queue_name, nil, no_ack: true)

    {:ok, channel}
  end

  # Confirmation sent by the broker after registering this process as a consumer.
  # required
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end
  
  def handle_info({:basic_deliver, payload, _}, chan) do
    # You might want to run payload consumption in separate Tasks in production
    IO.puts("Msj: #{payload}")
    {:noreply, chan}
  end

end
