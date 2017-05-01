class Dog
  def initialize(name)
    @name = name
  end

  def bowwow
    puts "Bowwow! My name is #{@name}!"
  end
end

Dog.new("Shiba Inu").bowwow
