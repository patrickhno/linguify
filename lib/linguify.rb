# encoding: utf-8

require 'linguify/linguified'
require 'linguify/reduction'
require 'linguify/sexp'
require 'linguify/string'
require 'linguify/proc'

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
  Linguify::rules << rule
end

module Linguify

  def self.rules
    @@rules ||= []
  end

end


