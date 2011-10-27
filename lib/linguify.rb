# encoding: utf-8

require 'linguify/linguified'
require 'linguify/reduction'
require 'linguify/sexp'
require 'linguify/string'
require 'linguify/proc'

# Defines a reduction rule.
#
# @param [ Hash ] pattern The step matching pattern
# @param [ Proc ] code    The code
#
#   The step matching pattern only one key-value pair, where the
#     key is the step matching pattern and the
#     value is on of:
#       nil      - indicating the last reduction,
#       +String+ - the name of the reduction,
#       +Hash+   - the name of the reduction and adittional parameters
#
#   Supported parameters:
#     :to     - the name of the reduction
#     :lang   - what language the code block translates to. (:ruby or :js)
#     :inline - if true, calls to this reduction will be inlined
#
# @example Define a reduction rule that reduce a text to a javascript reduction named query.
#   reduce /a possible javascript NOSQL query/ => {:to => 'query', :lang => :js} do
#     @db.forEach(lambda{ |record|
#         emit(record);
#       }
#     )
#   end
#
def reduce(regexp,&code)
  rule = if regexp.kind_of? Regexp
    {
      :match  => regexp,
      :result => '',
      :lang   => :ruby,
      :inline => false,
      :proc => code
    }
  elsif regexp.values[0].kind_of?(Hash)
    {
      :match  => regexp.keys[0],
      :result => regexp.values[0][:to]     || '',
      :lang   => regexp.values[0][:lang]   || :ruby,
      :inline => regexp.values[0][:inline] || false,
      :proc => code
    }
  else
   {
      :match  => regexp.keys[0],
      :result => regexp.values[0],
      :lang   => :ruby,
      :inline => false,
      :proc => code
    }
  end
  Linguify::rules << rule
end

module Linguify

  def self.rules
    @@rules ||= []
  end

end


