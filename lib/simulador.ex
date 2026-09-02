defmodule Simulador do

  def simular_compra(producto) do
    forma_entrega = if Enum.random(1..100) <= 70, do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    confirma_compra? = Enum.random(1..100) <= 80
    Libremarket.Ui.comprar(producto, forma_entrega, medio_pago, confirma_compra?)
  end

  def simular_compra() do
    forma_entrega = if Enum.random(1..100) <= 70, do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    confirma_compra? = Enum.random(1..100) <= 80
    Libremarket.Ui.comprar(:rand.uniform(10), forma_entrega, medio_pago, confirma_compra?)
  end

  def simular_compras_secuencial(cantidad \\ 1) do
    resultados = for _n <- 1 .. cantidad do
      simular_compra()
    end
    Enum.frequencies(resultados)
  end

  def simular_compras_async(cantidad \\ 1) do
    resultados = for _n <- 1 .. cantidad do
      Task.async(fn -> simular_compra() end)
    end
    Task.await_many(resultados)
    Enum.frequencies(resultados)
  end

end
