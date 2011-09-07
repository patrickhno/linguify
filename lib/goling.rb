# encoding: utf-8

require 'goling/linguified'
require 'goling/reduction'

def reduce(regexp,&code)
  Goling::rules << { :match => regexp.keys[0], :result => regexp.values[0], :proc => code }
end

module Goling

  def self.rules
    @@rules ||= []
  end

end

class String
  def linguify bind=binding
    return Goling::Linguified::cace[self] if Goling::Linguified::cache[self]
    Goling::Linguified::cache[self] = Goling::Linguified.new(self,bind)
  end
end
