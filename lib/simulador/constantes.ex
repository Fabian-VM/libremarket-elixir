defmodule Constantes do

  def compras_queue, do: "compras"
  def infracciones_queue, do: "infracciones"
  def ventas_queue, do: "ventas"
  def envios_queue, do: "envios"
  def pagos_queue, do: "pagos"

  def prob_pago_autorizado, do: 70
  def prob_forma_entrega_correo, do: 70
  def prob_usuario_confirma, do: 80
  def prob_infraccion, do: 30

end
