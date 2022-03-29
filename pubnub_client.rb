require 'pubnub'

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
   value = `ping -c 1 #{params}`
   return_message = {"value": value}
   puts return_message
   @pubnub.publish(channel: CHANNEL, message: return_message) do |env|
      puts env.status
   end
end

def calibrate(params)
   puts "calibrate"
   result = rand(100)
   return_message = {"value": "#{result} gr"}
   @pubnub.publish(channel: CHANNEL, message: return_message) do |env|
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