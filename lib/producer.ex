defmodule Producer do
  @moduledoc """
  Módulo para enviar mensajes a RabbitMQ.
  """
  use AMQP

  def send_message(queue_name, message) do
    # Obtener el canal AMQP (definido en la configuración)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    # Publicar el mensaje
    Basic.publish(channel, "", queue_name, :erlang.term_to_binary(message))

    IO.puts("Mensaje enviado")
  end

end
