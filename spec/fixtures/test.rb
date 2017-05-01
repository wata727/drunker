class Cat
  def initialize(name)
    @name = name
  end

  def meow
    puts "Meow! My name is #{@name}!"
  end
end

Cat.new("Munchkin").meow
