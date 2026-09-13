defmodule Simulador do

  def show_state(queue) do
    Producer.send_message(queue, {:show_state})
  end

  def simular_compra(producto) do
    forma_entrega = if Enum.random(1..100) <= 70, do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    confirma_compra = Enum.random(1..100) <= 80
    Producer.send_message("ui", {:simular_compra, producto, forma_entrega, medio_pago, confirma_compra})
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
