import Config

config :libremarket, Repositorio,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASSWORD"),
  hostname: System.fetch_env!("DB_HOST"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  database: System.fetch_env!("DB_NAME"),
  pool_size: 5
