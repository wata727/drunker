module Drunker
  class CLI < Thor
    desc "version", "Print version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
