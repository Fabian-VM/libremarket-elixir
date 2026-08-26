defmodule Libremarket.Ui do

  def comprar(producto_id, medio_pago, forma_entrega) do
    _compra_id = Libremarket.Compras.Server.comprar(producto_id, medio_pago, forma_entrega)
  end

end
