# encoding: utf-8

class String
  def linguify bind=binding
    return Goling::Linguified::cache[self] if Goling::Linguified::cache[self]
    Goling::Linguified::cache[self] = Goling::Linguified.new(self,bind)
  end
end

