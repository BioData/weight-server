require 'pubnub'
require 'net/ping'
require 'rest-client'
require 'socket'

class SocketCommandExecutor
  def initialize(host, port, cmd, expected_number_of_responses = 1, max_wait_time = 1, pubnub)
    @host = host.strip
    @port = port.strip
    @cmd = cmd.strip
    @expected_number_of_responses = expected_number_of_responses.to_i
    @max_wait_time = max_wait_time.to_i + 20
    @pubnub = pubnub
  end

  def execute
    socket = TCPSocket.open(@host, @port) # Connect to server
    puts "Connected to #{@host} on port #{@port}"
    last_read = []
    mutex = Mutex.new

    begin
      # reader_thread = Thread.new do
      #   while line = socket.gets # Here we are reading line coming from the socket
      #     puts "Reading from socket: #{line}"
      #     mutex.synchronize do
      #       last_read << line.chop
      #     end
      #   end
      # end

      reader_thread = Thread.new do
        while line = socket.gets(timeout: 20) # example timeout for reading
          puts "Reading from socket: #{line}"
          last_read << line.chop
        end
     end

      puts "Sending command: #{@cmd}"
      socket.puts("#{@cmd}\r\n")

      # Wait for the reader thread to finish or timeout
      Timeout.timeout(@max_wait_time.to_i) do
        reader_thread.join
      end

    rescue StandardError => e
      error_msg = "SocketCommandExecutor error: Failed to execute command '#{@cmd}' on #{@host}:#{@port}. Error: #{e.message}"
      puts error_msg
      publish_message("#{LGPINUM}: #{error_msg}")
    ensure
      reader_thread.kill if reader_thread && reader_thread.alive?
      socket.close if socket && !socket.closed?
      puts 'Socket closed'
    end

    last_read.join("\n")
  end
end

# Read configuration from file
lines = File.readlines('comm.dat').map(&:chomp)
PUBLISH_KEY = lines[0]
SUBSCRIBE_KEY = lines[1]
FLOW_CREDS = lines[2]
SERVER = lines[3]
LGPINUM = lines[4]
puts PUBLISH_KEY
CHANNEL = 'scales'
# commands = {get_weight: "get_weight",
#             reboot: "reboot",
#             update: "update",
#             calibrate: "calibrate",

# PubNub setup
@pubnub = Pubnub.new(
  publish_key: PUBLISH_KEY,
  subscribe_key: SUBSCRIBE_KEY,
  ssl: true,
  max_retries: 1,
  uuid: 'pace1'
)

def publish_message(message)
  @pubnub.publish(channel: CHANNEL, message: message) do |env|
    puts env.status
  end
end

def post_to_server(data)
  response = RestClient.post(SERVER, data)
  puts "response: #{response}"
rescue StandardError => e
  error_msg = "Failed to post data to Labguru: #{e.message}"
  puts error_msg
  publish_message("#{LGPINUM}: #{error_msg}")
end

def simulate(_params)
  puts 'simulate'
  result = rand(100)
  return_message = { value: "#{result} gr" }
  publish_message("#{LGPINUM}: #{return_message}")
  post_to_server(item: return_message)
end

def get_device_ip(_params)
  ip = Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
  ip ||= 'Could not find IP'
  publish_message("#{LGPINUM}: #{ip}")
end

def get_weight(params)
  ip, port = params.values_at('ip', 'port')
  value = execute_socket_command(ip, port, 'S', '1', '5')
  puts "value from balance = #{value}"
  publish_message("#{LGPINUM}: #{value}")
  post_to_server(item: { value: value, ip: ip, port: port })
end

def get_weight_with_fallback(params)
  value = get_weight(params)
  return unless value.nil? || value.empty?

  value = 'Balance did not respond'
  publish_message("#{LGPINUM}: #{value}")
end

def ping(params)
  png = Net::Ping::HTTP.new(params)
  publish_message("#{LGPINUM}: #{png.ping?}")
  puts("ping #{params} #{png.ping?}")
end

def ping_equipment(params)
  ip, port = params.values_at('ip', 'port')
  value = execute_socket_command(ip, port, 'TIM', '1', '5')
  publish_message("#{LGPINUM}: #{value}")

  return unless value.nil? || value.empty?

  value = 'Balance did not respond'
  publish_message("#{LGPINUM}: #{value}")
  post_to_server(item: { value: value })
end

def echo(_params)
  publish_message("#{LGPINUM}: I'm Here")
end

def get_datfile(_params)
  lines = File.read('comm.dat')
  publish_message("#{LGPINUM}: #{lines}")
end

def update_params(params)
  lines = File.readlines('comm.dat').map(&:chomp)
  return unless params['LGPINUM'] == LGPINUM

  lines[params['line']] = params['value']
  begin
    File.write('comm.dat', lines.join("\n"))
    publish_message("#{LGPINUM}: Updated")
  rescue StandardError => e
    publish_message("#{LGPINUM}: Error updating file - #{e.message}")
    puts "Failed to update file: #{e.message}"
  end
end

def healthcheck(params)
  puts "healthcheck #{params}"
  df = `df / -h`
  df = df.gsub('Filesystem', '')
  df = df.gsub('Size', '')
  df = df.gsub("Used Avail Use% Mounted on\n/dev/root        ", '').gsub("/\n", '')
  temp = `vcgencmd measure_temp`
  mem = `vcgencmd get_mem arm   `
  publish_message("#{LGPINUM}: #{df} \n #{temp} \n #{mem}")
  publish_message("#{LGPINUM}")
end

def update_pi(_params)
  publish_message("#{LGPINUM}: updating")
  `sudo apt-get update -y`
  `sudo apt-get upgrade --fix-missing -y`
  publish_message("#{LGPINUM}: updated")
end

def update_repo(_params)
  publish_message("#{LGPINUM}: updating repo")
  value = `git pull origin`
  publish_message("#{LGPINUM}: #{value}")
end

def reboot(params)
  puts "ping #{params}"
  publish_message("#{LGPINUM}: rebooting")
  sleep 2
  `sudo reboot`
end

def remote_cmd(params)
  ip, port, cmd = params.values_at('ip', 'port', 'cmd')
  value = execute_socket_command(ip, port, cmd, params['arg1'], params['arg2'])
  publish_message("#{LGPINUM}: #{value}")
  post_to_server(item: { value: value, ip: ip, port: port })
end

def execute_socket_command(ip, port, cmd, num_of_lines, time_to_wait)
  executor = SocketCommandExecutor.new(ip, port, cmd, num_of_lines, time_to_wait, @pubnub)
  executor.execute
end

callback = Pubnub::SubscribeCallback.new(
  message: lambda { |envelope|
    begin
      puts "Received message: #{envelope.result[:data]}"
      message = envelope.result[:data][:message]

      if message.is_a?(Hash)
        cmd = message['cmd']
        params = message['params']
        send(cmd.to_sym, params) if cmd
      else
        puts "********** Unexpected message format: #{message.class} - #{message.inspect}"
      end
    rescue StandardError => e
      puts "********** Error processing message: #{e.message} - #{message.inspect}"
    end
  }
)

@pubnub.add_listener(callback: callback)
@pubnub.subscribe(channels: [CHANNEL], with_presence: true)

publish_message("#{LGPINUM}: I'm up")

time = Time.now
while true
  # do nothing
  if Time.now > time + 60 * 5 # every 5 minutes
     healthcheck({})
    time = Time.now
  end
end
