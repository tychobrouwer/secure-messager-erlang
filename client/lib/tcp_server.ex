defmodule TCPServer do
  @moduledoc """
  Documentation for `TCPServer`.
  """

  require Logger

  @spec connect(charlist, integer) :: :ok
  def connect(address, port) do
    case :gen_tcp.connect(address, port, [:binary, packet: :line, active: true, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Connection on #{address}:#{port}")

        pid = self()

        Registry.register(TCPServer.Registry, 'pid', pid)

        loop_serve(socket)

      {:error, reason} ->
        Logger.error("Error: #{reason}")

        Process.sleep(100)

        exit(:unable_to_connect)
    end
  end

  defp loop_serve(socket) do
    receive do
      # Handling incoming packets (in active mode)
      {:tcp, ^socket, data} ->
        Logger.info("Received: #{data}")

      # Handling TCP closed connection
      {:tcp_closed, ^socket} ->
        Logger.error("Connection closed")
        exit(:disconnect)

      # Handling TCP errors
      {:tcp_error, ^socket, reason} ->
        Logger.error("TCP Error: #{reason}")
        exit(:error)

      # Handle sending messages to the socket
      {:send_message, message} ->
        send_data(message, socket)
    after
      5000 ->
        nil
    end

    # Loop back to serve
    loop_serve(socket)
  end

  # Function to send a message to the server
  defp send_data(message, socket) do
    case :gen_tcp.send(socket, message) do
      :ok ->
        Logger.info("Sent: #{message}")

      {:error, reason} ->
        Logger.error("Failed to send message: #{reason}")
    end
  end

  # Public API to send a message from another process
  def send_message(pid, message) do
    send(pid, {:send_message, message})
  end
end
