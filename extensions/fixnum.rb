class Fixnum
  def commas
    self.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end
end
class Float
  def commas
    self.to_i.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end
end