require 'socket'
host = ARGV[0].gsub("\n","")     # The web server
port = ARGV[1].gsub("\n","")     # The web port 8080                          # Default HTTP port
cmd  = ARGV[2].gsub("\n","")     # cmd "S for scale" "C1 for calibraiton"
expected_number_of_responses = ARGV[3].gsub("\n","") || 1
max_wait_time = 1
if ARGV[4]
  max_wait_time = ARGV[4].gsub("\n","")
end
# This is the HTTP request we send to fetch a file
socket = TCPSocket.open(host,port)  # Connect to server
last_read = []
mutex = Mutex.new
Thread.new do |t|
  mutex.synchronize do
    while line = socket.gets # Here we are reading line coming from the socket
        last_read << line.chop
        puts line.chop 
    end
  end
end
socket.puts("#{cmd}\r\n")
i = 0

while last_read.length < expected_number_of_responses.to_i
 sleep 1
 i += 1
 if i > max_wait_time.to_i
  break
 end
end

puts last_read.join("\n")
