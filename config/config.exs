import Config

# Configuración para la conexión AMQP, se carga desde variable de entorno CLOUDAMQP_URL
config :amqp,
  connections: [
    # sin certtificados SSL
    connection: [url: System.get_env("CLOUDAMQP_URL") || "amqp://guest:guest@localhost:5672/", ssl_options: [verify: :verify_none]]
  ],
  channels: [
    channel: [connection: :connection]
  ]
