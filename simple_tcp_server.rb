require 'socket'

class SimpleTCPServer
  def initialize(host, port)
    @server = TCPServer.new(host, port)
    puts "Server started on #{host}:#{port}"
  end

  def start
    loop do
      client = @server.accept
      Thread.new(client) do |client_socket|
        handle_client(client_socket)
      end
    end
  end

  private

  def handle_client(client)
    loop do

      request = client.gets&.chomp
      request = request.gsub("-e", "").gsub(" ", "") if request

      puts "handle_client request:#{request.inspect}"
      break if request.nil? || request.empty?

      puts "Received request: #{request.inspect}"

      response = case request
                when 'S'   then "Weight: 75kg, You look awesome, don't worry about the weight"
                when 'TIM' then "Time: #{Time.now}"
                when 'SI'  then "SI Response,  You look awesome, don't worry about the weight"
                when 'S'  then "S response, You look awesome, don't worry about the weight"
                else "Unknown command"
                end

      client.puts response
      puts "Sent response: #{response}"

      client.close if request == 'exit' # Close the connection if 'exit' command is received
    end
  rescue StandardError => e
    puts "Error handling client: #{e.message}"
  ensure
    client.close unless client.closed?
  end
end

# Start the server on localhost and port 8080
server = SimpleTCPServer.new('localhost', 8082)
server.start
