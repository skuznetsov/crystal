require "http/server"

module Crweb
  VERSION = "0.1.0"
  port = 3000

  def self.startHTTPServer(serverPort)
    server = HTTP::Server.new do |context|
      puts "Got request"
      context.response.content_type = "text/plain"
      context.response.print "!"
    end

    server.listen(serverPort)
  end

  puts "PID=#{Process.pid}"
  puts "Initial port: #{port}"

  puts "Listening on http://127.0.0.1:#{port}"

  startHTTPServer port
end
