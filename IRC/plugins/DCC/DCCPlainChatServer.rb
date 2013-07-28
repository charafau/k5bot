# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Direct Client-to-Client plain chat server

require 'gserver'

require_relative '../../ContextMetadata'

class DCCPlainChatServer < GServer
  attr_reader :port_to_bot
  attr_reader :config

  def initialize(dcc_plugin, config)
    super(config[:port] || dcc_plugin.class::DEFAULT_LISTEN_PORT,
          config[:listen] || dcc_plugin.class::DEFAULT_LISTEN_INTERFACE,
          config[:limit] || dcc_plugin.class::DEFAULT_CONNECTION_LIMIT,
          nil, true, true)

    @dcc_plugin = dcc_plugin
    @config = config

    @port_to_bot = {}
  end

  def starting
  end

  def stopping
  end

  def connecting(client_socket)
    caller_info = client_socket.peeraddr(true)
    # [host, ip] or [ip], if reverse resolution failed
    caller_id = caller_info[2..-1].uniq
    # [family, port, host, ip] or [family, port, ip]
    caller_info = caller_info.uniq

    do_log(:log, "Got incoming connection from #{caller_info}")

    credentials = caller_id.map { |id_part| @dcc_plugin.caller_id_to_credential(id_part) }
    authorizations = credentials.map { |cred| @dcc_plugin.get_credential_authorization(cred) }.reject { |x| !x }

    principals = authorizations.map { |principal, _| principal }.uniq

    unless authorizations.empty? || authorizations.any? { |_, is_authorized| is_authorized }
      do_log(:log, "Identified #{caller_info} as non-authorized #{principals}")
      # Drop connection immediately.
      return
    end

    create_dcc_chat(client_socket, caller_id, credentials, principals, caller_info)
  end

  def create_dcc_chat(client_socket, caller_id, credentials, principals, caller_info)
    client = DCCBot.new(client_socket, @dcc_plugin, @dcc_plugin.parent_ircbot)

    client.caller_info = caller_info
    client.credentials = credentials
    client.principals = principals

    if client.principals.empty?
      begin
        client.dcc_send("Unauthorized connection. Use command .#{@dcc_plugin.class::COMMAND_REGISTER} first.")

        caller_id.zip(client.credentials).each do |id, cred|
          client.dcc_send("To approve '#{id}' use: .#{@dcc_plugin.class::COMMAND_REGISTER} #{cred}")
        end
      rescue Exception => e
        do_log(:error, "Exception while declining #{caller_info}: #{e.inspect}")
      end

      false
    else
      @port_to_bot[socket_to_port(client_socket)] = client

      true
    end
  end

  def disconnecting(client_port)
    @port_to_bot.delete(client_port)

    do_log(:log, "Closing connection to #{client_port}")
  end

  def serve(client_socket)
    client_port = socket_to_port(client_socket)
    client = @port_to_bot[client_port]
    if client
      ContextMetadata.run_with(@config[:metadata]) do
        client.serve
      end
    else
      raise "Bug! #{self.class.to_s} attempted to serve unknown client on port #{client_port}"
    end
  end

  # Hack around Gserver's criminal inability
  # to properly force clients to stop.
  def shutdown
    # Mark gserver as shutting down.
    # This is so that it won't start raising
    # exceptions in client threads,
    super

    # Close listening socket to avoid hanging on accept()
    # indefinitely, while join()ing on server thread.
    @tcpServer.shutdown

    # Signal all clients to close
    while @connections.size > 0
      @port_to_bot.values.each do |client|
        client.close rescue nil
      end
      sleep(1)
    end
  end

  def error(e)
    do_log(:error, "#{e.inspect} #{e.backtrace.join("\n") rescue nil}")
  end

  def log(text)
    do_log(:log, text)
  end

  TIMESTAMP_MODE = {:log => '=', :in => '>', :out => '<', :error => '!'}

  def do_log(mode, text)
    puts "#{TIMESTAMP_MODE[mode]}DCC: #{Time.now}: #{self.class.to_s}: #{text}"
  end

  def socket_to_port(socket)
    socket.peeraddr(false)[1]
  end
end
