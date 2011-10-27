# encoding: utf-8

class String

  # Linguify the string.
  #
  # @param   [ Binding ]    binding See the +Kernel#eval+.
  # @returns [ Linguified ] code    The compiled code
  #
  # @example Linguify a string and translate it back to Ruby
  #   "this is the famous hello world".linguify.to_ruby
  #   # => "code = lambda do
  #   #       (pp(\"hello world\")
  #   #     end
  #   #    "
  #
  def linguify bind=binding
    return Linguify::Linguified::cache[self] if Linguify::Linguified::cache[self]
    Linguify::Linguified::cache[self] = Linguify::Linguified.new(self,bind)
  end

end

