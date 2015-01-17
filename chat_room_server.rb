require 'socket'
require 'thread'

class ChatRoomServer

def initialize
  @port = 8000
  @running = true
  @server = TCPServer.new @port
  @rooms = []
  @num_rooms = 0
  @mutex = Mutex.new

  while @running do
    client = @server.accept
    Thread.new do
      Thread.abort_on_exception =true
      handle(client)
    end
  end
end

def handle(client)#handle client by waiting for their message then calling whatever method
  loop{
    while message = client.gets do
      message += get_rest_of_msg(message,client)
      case message
        when /\AHELO/ then
          ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
          client.puts "#{message}IP: #{ip}\nPort: #{@port}\nStudent ID: 11534207\n"

        when /\AKILL_SERVICE\n\z/ then
          self.shutdown

        when /\AJOIN_CHATROOM: (\S+)\nCLIENT_IP: 0\nPORT: 0\nCLIENT_NAME: (\S+)/ then
          room,join_id = add_to_room($1,$2,client)
          send_join_notif_to_room(room,$2)
          ip = Socket.ip_address_list.find { |ai| ai.ipv4? && !ai.ipv4_loopback? }.ip_address
          client.puts "JOINED_CHATROOM: #{room.name}\nSERVER_IP: #{ip}\nPORT: #{@port}\nROOM_REF: #{room.ref}\nJOIN_ID: #{join_id}\n"

        when /\ALEAVE_CHATROOM: (\d+)\nJOIN_ID: (\d+)\nCLIENT_NAME: (\S+)/ then
          room = get_room_by_ref($1)
          the_client = room.get_client($2,$3)
          if room == nil
            client.puts "ERROR_CODE: 0001\nERROR_DESCRIPTION: No room exists with the ref you have provided\n"
          elsif the_client == nil
            client.puts "LEFT_CHATROOM: #{$1}\nJOIN_ID: #{$2}\n"
          else
            remove_from_room(room,the_client)
            send_left_notif_to_room(room,the_client)
            client.puts "LEFT_CHATROOM: #{room.ref}\nJOIN_ID: #{the_client.join_id}\n"
          end

        when /\ADISCONNECT: 0\nPORT: 0\nCLIENT_NAME: (\S+)/ then
          client.close

        when /\ACHAT: (\d+)\nJOIN_ID: (\d+)\nCLIENT_NAME: (\S+)\nMESSAGE: (.*)\n\n/ then
          room = get_room_by_ref($1)
          the_client = room.get_client($2,$3)
          if room == nil
            client.puts "ERROR_CODE: 0001\nERROR_DESCRIPTION: No room exists with the ref you have provided\n"
          elsif the_client == nil
            client.puts "ERROR_CODE: 0002\nERROR_DESCRIPTION: No matching client found in the room with the details you have provided\n"
          else
            send_msg_to_all_in_room(room,the_client,$4)
          end
        else
          client.puts "ERROR_CODE: 0000\nERROR_DESCRIPTION: Unrecognized command\n"
      end
    end
  }
end

  def get_rest_of_msg(message,client)
    case message
      when /\AJOIN/
        return client.gets+client.gets+client.gets
      when /\ACHAT/
        return client.gets+client.gets+client.gets+client.gets
      when /\ALEAVE/
        return client.gets+client.gets
      when /\ADISCONNECT/
        return client.gets+client.gets
      else
        puts message
    end

  end

  def send_msg_to_all_in_room(room,client,message)
    room.clients.each do |current_client|
      current_client.conn.puts "CHAT: #{room.ref}\nCLIENT_NAME: #{client.name}\nMESSAGE: #{message}\n\n"
    end
  end

  def send_join_notif_to_room(room,name)
    room.clients.each do |current_client|
      current_client.conn.puts "#{name} JOINED ROOM #{room.ref}\n"
    end
  end

  def send_left_notif_to_room(room,name)
    room.clients.each do |current_client|
      current_client.conn.puts "#{name} LEFT ROOM #{room.ref}\n"
    end
  end

  def add_to_room(room_name,client_name,client_connection)
    room = get_room_by_name(room_name)
    join_id = -1
    if room == nil
      @mutex.lock
      room = ChatRoom.new(room_name,@num_rooms)
      @num_rooms+=1
      @mutex.unlock
      @rooms << room
    end

    new_client = Client.new(client_name,room.num_clients,client_connection)
    room.mutex.lock
    join_id = room.num_clients
    room.num_clients+=1
    room.mutex.unlock
    room.clients << new_client

    return room, join_id
  end

  def remove_from_room(room,client)
    room.clients.delete(client)
  end

  def get_room_by_name(name)
    @rooms.each do |room|
      return room if room.name == name
    end
    nil
  end

  def get_room_by_ref(ref)
    @rooms.each do |room|
      return room if room.ref == ref.to_i
    end
    nil
  end

  def shutdown#as soon as we get a kill service, stop everything
    puts "Server shutdown"
    @server.close
    Thread.list.each do |thread|
      thread.kill
    end
  end

end

class ChatRoom
  @num_clients
  @ref = nil
  @clients
  @name = nil
  @mutex

  attr_accessor :num_clients,:clients,:ref,:name,:mutex

  def initialize (name,ref)
    @name = name
    @ref = ref
    @clients = Array.new
    @num_clients = 0
    @mutex = Mutex.new
  end

  def get_client(join_id,name)
    @clients.each do |client|
      return client if client.join_id == join_id.to_i && client.name == name
    end
    nil
  end
end

class Client
  @name = nil
  @join_id = nil
  @conn = nil

  attr_accessor :name,:join_id,:conn

  def initialize(name,join_id,connection)
    @name = name
    @join_id = join_id
    @conn = connection
  end
end

ChatRoomServer.new