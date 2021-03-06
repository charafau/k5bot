# encoding: utf-8
# This file is part of the K5 bot project.
# See files README.md and COPYING for copyright and licensing information.

# MenuNodeSimple is a straightforward implementation of MenuNode interface

class Menu
class MenuNodeSimple < MenuNode
  attr_accessor :entries

  def initialize(description, entries)
    @description = description
    @entries = entries
  end

  def enter(from_child, msg)
    @entries
  end
end
end