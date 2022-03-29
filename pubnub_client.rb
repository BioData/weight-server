require 'pubnub'
require 'net/ping'

lines = File.readlines("comm.dat")
PUBLISH_KEY=lines[0].gsub("\n","")
SUBSCRIBE_KEY=lines[1].gsub("\n","")
FLOW_CREDS=lines[2].gsub("\n","")
puts PUBLISH_KEY
CHANNEL = "scales"
# commands = {get_weight: "get_weight",
#             reboot: "reboot",
#             update: "update",
#             calibrate: "calibrate",

def simulate(params)
    puts "simulate"
    result = rand(100)
    return_message = {"value": "#{result} gr"}
    @pubnub.publish(channel: CHANNEL, message: return_message) do |env|
       puts env.status
    end
end

def ping(params)
   puts "ping #{params}"
   png = Net::Ping::HTTP.new(params)
   return_message = {"value": png.ping?}
   puts return_message
   @pubnub.publish(channel: CHANNEL, message: return_message) do |env|
      puts env.status
   end
end

def update_repo(params)
   puts "update_repo #{params}"
   @pubnub.publish(channel: CHANNEL, message: "updating repo") do |env|
      puts env.status
   end
   value = `git pull origin`
   @pubnub.publish(channel: CHANNEL, message: "value") do |env|
      puts env.status
   end
end

def reboot(params)
   puts "ping #{params}"
   @pubnub.publish(channel: CHANNEL, message: "rebooting") do |env|
      puts env.status
   end
   `sudo reboot`
end

def calibrate(params)
   puts "calibrate"
   ip = params["ip"]
   port = params["port"]
   value = `ruby mt.rb #{ip} #{port} C1 10`
   @pubnub.publish(channel: CHANNEL, message: value) do |env|
      puts env.status
   end
end

@pubnub = Pubnub.new(publish_key: PUBLISH_KEY,
   subscribe_key: SUBSCRIBE_KEY,
   ssl: true,
   max_retries: 1,
   uuid: 'pace1')

callback = Pubnub::SubscribeCallback.new(
  message: ->(envelope){
     puts "MESSAGE: #{envelope.result[:data]}"
     cmd = envelope.result.dig(:data,:message,'cmd')
     params = envelope.result.dig(:data,:message,'params')
     send(cmd.to_sym,params)
  }
)

@pubnub.add_listener(callback: callback)

@pubnub.subscribe( channels:[CHANNEL],  with_presence: true)

@pubnub.publish(channel: CHANNEL, message: {text: 'hello world'}) do |env|
  puts env.status
end



while(true)
 #do nothing
end