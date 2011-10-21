
require 'goling/linguified'
require 'goling/reduction'
require 'goling/sexp'
require 'goling/string'
require 'goling/proc'

def reduce(regexp,&code)
  rule = regexp.values[0].kind_of?(Hash) ? {
    :match  => regexp.keys[0],
    :result => regexp.values[0][:to]     || '',
    :lang   => regexp.values[0][:lang]   || :ruby,
    :inline => regexp.values[0][:inline] || false,
    :proc => code
  } : {
    :match  => regexp.keys[0],
    :result => regexp.values[0],
    :lang   => :ruby,
    :inline => false,
    :proc => code
  }
  Goling::rules << rule
end

module Goling

  def self.rules
    @@rules ||= []
  end

end


