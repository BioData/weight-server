require 'pubnub'
require 'net/ping'
require 'rest-client'
require 'socket'
require 'open3'

class SocketCommandExecutor
   def initialize(host, port, cmd, expected_number_of_responses = 1, max_wait_time = 1, pubnub)
      @host = host.strip
      @port = port.strip
      @cmd = cmd.strip
      @expected_number_of_responses = expected_number_of_responses.to_i
      @max_wait_time = max_wait_time.to_i
      @pubnub = pubnub
   end

   def execute
      command = build_command
      puts("command #{command}")
      last_read = []

      stdout_str, stderr_str, status = Open3.capture3(command)
      if status.success?
         last_read = stdout_str.lines.map(&:chomp)
      else
         puts "Error: #{stderr_str.inspect}"
      end

      sleep @max_wait_time
      last_read.join("\n")
   rescue => e
      error_msg = "An error occurred: #{e.message}"
      puts error_msg
      publish_message(error_msg)
   end

   private

   def build_command
      "echo -e \"#{@cmd}\\r\\n\" | nc #{@host} #{@port}"
   end
end

# Read configuration from file
lines = File.readlines("comm.dat").map(&:chomp)
PUBLISH_KEY=lines[0]
SUBSCRIBE_KEY=lines[1]
FLOW_CREDS=lines[2]
SERVER=lines[3]
LGPINUM=lines[4]
puts PUBLISH_KEY
CHANNEL = "scales"
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
   puts response
rescue => e
   error_msg = "Failed to post data to Labguru: #{e.message}"
   puts error_msg
   publish_message(error_msg)

end

def simulate(params)
   puts "simulate"
   result = rand(100)
   return_message = { value: "#{result} gr" }
   publish_message(return_message)
   post_to_server(item: return_message)
end

def get_device_ip(params)
   ip = Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address
   ip ||= 'Could not find IP'
   publish_message(ip)
end

def get_weight(params)
   ip, port = params.values_at("ip", "port")
   value = execute_socket_command(ip, port, 'S', '1', '5')
   publish_message(value)
   post_to_server(item: { value: value, ip: ip, port: port })
end

def get_weight_with_fallback(params)
   value = get_weight(params)
   if value.nil? || value.empty?
     value = "Balance did not respond"
     publish_message(value)
   end
end

def ping(params)
   png = Net::Ping::HTTP.new(params)
   publish_message("#{LGPINUM}: #{png.ping?}")
   puts ("ping #{params} #{png.ping?}")
end

def ping_equipment(params)
   ip, port = params.values_at("ip", "port")
   value = execute_socket_command(ip, port, "TIM", '1', '5')
   publish_message(value)

   if value.nil? || value.empty?
     value = "Balance did not respond"
     publish_message(value)
     post_to_server(item: { value: value })
   end
end

def echo(params)
   publish_message("#{LGPINUM}: I'm Here")
end

def get_datfile(params)
   lines = File.read("comm.dat")
   publish_message("#{LGPINUM}: #{lines}")
end

def update_params(params)
   lines = File.readlines("comm.dat").map(&:chomp)
   if params["LGPINUM"] == LGPINUM
     lines[params["line"]] = params["value"]
     begin
       File.write("comm.dat", lines.join("\n"))
       publish_message("#{LGPINUM}: Updated")
     rescue => e
       publish_message("#{LGPINUM}: Error updating file - #{e.message}")
       puts "Failed to update file: #{e.message}"
     end
   end
end

def healthcheck(params)
   puts "healthcheck #{params}"
   df= `df / -h`
   df = df.gsub("Filesystem", "")
   df = df.gsub("Size","")
   df = df.gsub("Used Avail Use% Mounted on\n/dev/root        ","").gsub("/\n","")
   temp = `vcgencmd measure_temp`
   mem = `vcgencmd get_mem arm   `
   publish_message("#{LGPINUM}: #{df} \n #{temp} \n #{mem}")
   publish_message("#{LGPINUM}")
end

def update_pi(params)
   publish_message("#{LGPINUM}: updating")
   `sudo apt-get update -y`
   `sudo apt-get upgrade --fix-missing -y`
   publish_message("#{LGPINUM}: updated")
end

def update_repo(params)
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
   ip, port, cmd = params.values_at("ip", "port", "cmd")
   value = execute_socket_command(ip, port, cmd, params['arg1'], params['arg2'])
   publish_message("#{LGPINUM}: #{value}")
   post_to_server(item: { value: value, ip: ip, port: port })
end


def execute_socket_command(ip, port, cmd, num_of_lines, time_to_wait)
   executor = SocketCommandExecutor.new(ip, port, cmd, num_of_lines, time_to_wait, @pubnub)
   executor.execute
end

callback = Pubnub::SubscribeCallback.new(
   message: ->(envelope) {
      begin
         puts "Received message: #{envelope.result[:data]}"
         message = envelope.result[:data][:message]

         if message.is_a?(Hash)
            cmd = message['cmd']
            params = message['params']
            send(cmd.to_sym, params) if cmd
         else
            puts "********** Unexpected message format: #{message.class} - #{message}"
         end
      rescue => e
         puts "********** Error processing message: #{e.message}"
      end
   }
)

@pubnub.add_listener(callback: callback)
@pubnub.subscribe( channels:[CHANNEL],  with_presence: true)

publish_message("#{LGPINUM}: I'm up")

time = Time.now
while(true)
 #do nothing
 if Time.now > time + 60 * 5   #every 5 minutes
   healthcheck({})
   time = Time.now
 end
end
