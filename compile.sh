# In order to access and save notebooks directly to your machine
# you can mount a local directory into the container.
# Make sure to specify the user with "-u $(id -u):$(id -g)"
# so that the created files have proper permissions
docker run -it --rm -v "$(pwd)":/app -w /app -u $(id -u):$(id -g) -e MIX_HOME=/app/mix_home -e HEX_HOME=/app/hex_home elixir:alpine mix compile
