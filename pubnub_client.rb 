require 'pubnub'

lines = File.readlines("comm.dat")
PUBLISH_KEY=lines[0]
SUBSCRIBE_KEY=lines[1]
FLOW_CREDS=lines[2]

CHANNEL = "scales"
commands = {get_weight: "get_weight", 
            reboot: "reboot",
            update: "update",
            calibrate: "calibrate",
            simulate: "simulate"}

def simulate
    result = rand(100)
    return_message = {"value": "#{result} gr"}
    reply = return_message.merge(FLOW_CREDS)
    pubnub.publish(channel: CHANNEL, message: reply) do |env|
       puts env.status
    end
end 

pubnub = Pubnub.new(publish_key: PUBLISH_KEY,
   subscribe_key: SUBSCRIBE_KEY,
   ssl: true,
   max_retries: 1,
   uuid: 'pace1')

callback = Pubnub::SubscribeCallback.new(
  message: ->(envelope){
     puts "MESSAGE: #{envelope.result[:data]}"
     cmd = envelope.result.dig(:data,:message,'cmd')
     params = envelope.result.dig(:data,:message,'params')
     if commands[cmd]
        commands[cmd].call(params)
     end 
  }
)

pubnub.add_listener(callback: callback)

pubnub.subscribe( channels:[CHANNEL],  with_presence: true)

pubnub.publish(channel: CHANNEL, message: {text: 'hello world'}) do |env|
  puts env.status
end



while(true)
 #do nothing
end