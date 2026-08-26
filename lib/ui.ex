defmodule Libremarket.Ui do

  def comprar(_producto, _medio_de_pago, _forma_de_entrega) do
    Libremarket.Compras.Server.comprar()
  end

end
