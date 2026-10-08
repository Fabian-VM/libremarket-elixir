defmodule Libremarket.Ui do
  @moduledoc """
  Módulo de lógica de la interfaz
  """

  def comprar(producto_id, forma_entrega, medio_pago, confirma_compra) do
    # La compra se inicia enviando un mensaje a la cola de mensajes del servidor de compras
    Middleware.send_message(
      Constantes.compras_queue(),
      {:simular_compra, producto_id, forma_entrega, medio_pago, confirma_compra}
    )
    :ok
  end

end
