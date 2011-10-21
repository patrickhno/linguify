
require 'goling/linguified'
require 'goling/reduction'
require 'goling/sexp'
require 'goling/string'
require 'goling/proc'

def reduce(regexp,&code)
  Goling::rules << {
    :match  => regexp.keys[0],
    :result => regexp.values[0].kind_of?(Hash)                                     ? regexp.values[0][:to]     : regexp.values[0],
    :lang   => regexp.values[0].kind_of?(Hash)                                     ? regexp.values[0][:lang]   : :ruby, 
    :inline => regexp.values[0].kind_of?(Hash)&&regexp.values[0].has_key?(:inline) ? regexp.values[0][:inline] : false,
    :proc => code
  }
end

module Goling

  def self.rules
    @@rules ||= []
  end

end


