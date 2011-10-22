# encoding: utf-8

class String
  def linguify bind=binding
    return Linguify::Linguified::cache[self] if Linguify::Linguified::cache[self]
    Linguify::Linguified::cache[self] = Linguify::Linguified.new(self,bind)
  end
end

