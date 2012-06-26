# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# Language points plugin

require_relative '../../IRCPlugin'

class LP < IRCPlugin
  Description = "A plugin that counts and manages language points. +1 if a message contains Japanese, otherwise -1."
  Commands = {
    :lp => "shows how many language points the specified user has"
  }
  Dependencies = [ :Language, :NumberSpell ]

  def afterLoad
    @l = @bot.pluginManager.plugins[:Language]
    @ns = @bot.pluginManager.plugins[:NumberSpell]
    @lp = @bot.storage.read('lp') || {}
  end

  def beforeUnload
    @lp = nil
    @ns = nil
  end

  def store
    @bot.storage.write('lp', @lp)
  end

  def on_privmsg(msg)
    case msg.botcommand
    when :lp
      nick = msg.tail || msg.nick
      user = @bot.userPool.findUserByNick(nick)
      if user && user.name
        if lp = @lp[user.name.downcase]
          msg.reply("Language points for #{user.nick}: #{format(lp)}")
        else
          msg.reply("#{user.nick} has no language points.")
        end
      else
        msg.reply('Cannot map this nick to a user at the moment, sorry.')
      end
    else
      unless msg.private?
        @lp[msg.user.name.downcase] = 0 unless @lp[msg.user.name.downcase]
        @lp[msg.user.name.downcase] += @l.containsJapanese?(msg.message) ? 1 : -1
        store
      end
    end
  end

  def format(num)
    @ns.spell(num)
  end

  def thousandSeparate(num)
    num.to_s.reverse.scan(/..?.?/).join(' ').reverse.sub('- ', '-') if num.is_a? Integer
  end
end
