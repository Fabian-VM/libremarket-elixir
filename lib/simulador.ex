defmodule Simulador do

  @doc """
  Envía un mensaje :show_state a la cola de mensajes especificada.
  Se espera que el proceso servidor que consuma ese mensaje, imprima su estado
  por la salida estándar.

  De esa forma no hace falta ingresar a dicho servidor para ejecutar el comando,
  sino únicamente leer su salida estándar.
  """
  def show_state(queue) do
    Producer.send_message(queue, {:show_state})
  end

  def simular_compra(producto_id) do
    forma_entrega = if Enum.random(1..100) <= 70, do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    confirma_compra = Enum.random(1..100) <= 80
    Libremarket.Ui.comprar(producto_id, forma_entrega, medio_pago, confirma_compra)
  end

  def simular_compra() do
    simular_compra(:rand.uniform(10))
  end

  def simular_compras_secuencial(cantidad \\ 1) do
    for _n <- 1 .. cantidad do
      simular_compra()
    end
  end

  def simular_compras_async(cantidad \\ 1) do
    tasks = for _n <- 1 .. cantidad do
      Task.async(fn -> simular_compra() end)
    end
    Task.await_many(tasks)
  end

end
