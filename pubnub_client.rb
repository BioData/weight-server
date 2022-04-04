require 'pubnub'
require 'net/ping'
require 'rest-client'

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

def simulate(params)
    puts "simulate"
    result = rand(100)
    return_message = {"value": "#{result} gr"}
    @pubnub.publish(channel: CHANNEL, message: return_message) do |env|
       puts env.status
    end
    data = {item: { value: "#{return_message || '???'}" }}
    RestClient.post(SERVER, data)
end

def get_weight(params)
   puts "get_weight"
   ip = params["ip"]
   port = params["port"]
   value = `ruby mt.rb #{ip} #{port} S 1 5`
   @pubnub.publish(channel: CHANNEL, message: value) do |env|
      puts env.status
   end
   if value.nil? || value == ''
    value ="???"
   end
   data = {item: { value: "#{value}" }}
   puts SERVER
   puts data
   res =   RestClient.post(SERVER, data)
   puts res
end

def ping(params)
   puts "ping #{params}"
   png = Net::Ping::HTTP.new(params)
   return_message = {"value": png.ping?}
   puts return_message
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: #{return_message}") do |env|
      puts env.status
   end
end

def echo(params)
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: I'm Here") do |env|
      puts env.status
   end
end

#{"cmd":"update_params","params":{"LGPINUM": "3", "line":5,"value":"test"}}
def update_params(params)
   updated = false 
   lines = File.readlines("comm.dat").map(&:chomp)
   if params["LGPINUM"] && params["LGPINUM"] == LGPINUM
      lines[params["line"]] = params["value"]
      begin 
        updated = File.write("comm.dat",lines.join("\n"))
      rescue 
        puts "ERR"
      end 
   else 
      lines[params["line"]] = params["value"]
      File.write("comm.dat",lines.join("\n"))
   end
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: Updated: #{updated}") do |env|
      puts env.status
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
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: #{df} \n #{temp} \n #{mem}") do |env|
      puts env.status
   end
end

def update_pi(params)
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}:updating") do |env|
      puts env.status
   end
  `sudo apt-get update -y`
  `sudo apt-get upgrade --fix-missing -y`
  @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: updated") do |env|
   puts env.status
  end
end

def update_repo(params)
   puts "update_repo #{params}"
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}:updating repo") do |env|
      puts env.status
   end
   value = `git pull origin`
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}:#{value}") do |env|
      puts env.status
   end
end

def reboot(params)
   puts "ping #{params}"
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}:rebooting") do |env|
      puts env.status
   end
   `sudo reboot`
end

def calibrate(params)
   puts "calibrate"
   ip = params["ip"]
   port = params["port"]
   value = `ruby mt.rb #{ip} #{port} C1 10`
   @pubnub.publish(channel: CHANNEL, message: "#{LGPINUM}: #{value}") do |env|
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

@pubnub.publish(channel: CHANNEL, message: {text: "#{LGPINUM}: I'm up"}) do |env|
  puts env.status
end


time = Time.now
while(true)
 #do nothing
 if Time.now > time + 60 * 5   #every 5 minutes
   healthcheck({})
   time = Time.now
 end
end