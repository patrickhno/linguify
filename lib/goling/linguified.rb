# encoding: utf-8

require 'sourcify'
require 'goling/translators/javascript'

module Goling

  class Linguified

    attr_accessor :proc, :sentence

    def initialize str,bind

      #
      # reduction loop
      #
      @sentence = str.dup
      @bind = bind
      loop do
        rule = find_rule(str)
        
        reduced = Reduction.new(
          :returns  => rule[:result],
          :lang     => rule[:lang],
          :inline   => rule[:inline],
          :location => rule[:proc].source_location[0],
          :line     => rule[:proc].source_location[1],
          :regexp   => rule[:match].inspect,
          :args     => rule[:match].match(str).to_a[1..-1],
          :sexp     => rule[:proc].to_sexp,
        )
        str.gsub!(rule[:match],reduced.to_rexp)
        break if /^{.*}$/ =~ str
      end

      @encoded = str

      @merged_code = []
      if /^{(?<code>.*)}$/ =~ @encoded
        # successfully reduced entire string, compile it
        code = Reduction::parse(code).compile_with_return_to_var(nil)

        # and wrap it up
        @sexy = Sexp.new(:block,
          Sexp.new(:lasgn,:code, Sexp.new(:iter,
            Sexp.new(:call, nil, :lambda, Sexp.new(:arglist)), nil,
              Sexp.new(:block,
                *code
              )
            )
          ),
        )

        @@me = self
        eval to_ruby(
            Sexp.new(:call,
              Sexp.new(:colon2, Sexp.new(:const, :Goling), :Linguified), :trampoline, Sexp.new(:arglist, Sexp.new(:lvar, :code))
            )
          ),bind
        raise "hell" unless @proc      
      else
        raise "hell"
      end
    end
    
    def find_rule str
      found = Goling.rules.select do |rule|
        if rule[:match] =~ str
          true
        else
          false
        end
      end
      raise "no step definition for #{str}" if found.size == 0

      found[0]
    end

    def to_sexp
      @sexy
    end

    def to_ruby additional=nil
      clone = Marshal.load(Marshal.dump(@sexy)) # sexy is not cleanly duplicated
      clone << additional if additional
      Ruby2Ruby.new.process(clone)
    end
    
    def run
      begin
        @proc.call
      rescue Exception => e
        $stderr.puts e
      end
    end
  
    def register_code code
      @proc = code
    end

    def self.trampoline code
      @@me.register_code code
    end
  
    def self.cache
      @@cache ||= {}
    end

  end

end
