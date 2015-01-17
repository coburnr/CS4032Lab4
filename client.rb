require 'socket'

class Client

  socket = TCPSocket.open 'localhost', 8000
  running = true
  entering = true
  message = ""
  temp = ""

  while running
    while entering
      temp = gets
      if temp == "send\n"
        entering = false
      elsif temp == "read\n"
        break
      else
        message = message + temp
      end
    end
    if temp != "read\n"
      socket.puts message
    end

    reading = true
    while reading
      line = socket.gets
      case line
        when /\AJOINED/
          line += socket.gets + socket.gets + socket.gets + socket.gets
        when /\ACHAT/
          line += socket.gets + socket.gets + socket.gets
        when /\ALEFT/
          line += socket.gets
        when /\AERROR/
          line += socket.gets
          running = false
        else
          line
      end
      puts line
      reading = false
    end
    entering = true
    message = ""
    temp = ""
  end

  socket.close
end