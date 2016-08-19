# Class storing the original file name
class NamedStringIO < StringIO
  def initialize(*args)
    super(*args[1..-1])
    @filename = args[0]
  end

  def original_filename
    @filename
  end
end
