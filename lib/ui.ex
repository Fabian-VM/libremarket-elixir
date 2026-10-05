defmodule Libremarket.Ui do
  @moduledoc """
  Módulo de lógica de la interfaz
  """
  @compras_queue_name "compras"

  def comprar(producto_id, forma_entrega, medio_pago, confirma_compra) do
    # La compra se inicia enviando un mensaje a la cola de mensajes del servidor de compras
    Producer.send_message(
      @compras_queue_name,
      {:simular_compra, producto_id, forma_entrega, medio_pago, confirma_compra}
    )
    :ok
  end

end
