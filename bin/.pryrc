
##### pryrc modifications to have cool feature in Expo Console.

 Pry.config.print = proc do |output, value|
  #### Modifying Pry output in order to better show outputs of std
   nonce = rand(0x100000000).to_s(16) # whatever
  
  if (value.kind_of? String ) and (value.include? "\n") then
      value.split("\n").each do |line|
        
        colorized = Pry::Helpers::BaseHelpers.colorize_code(line.pretty_inspect.gsub(/#</, "%<#{nonce}"))
        colorized = colorized.sub(/(\n*)$/, "\e[0m\\1") if Pry.color
        Pry::Helpers::BaseHelpers.stagger_output("=> #{colorized.gsub(/%<(.*?)#{nonce}/, '#<\1')}", output)
      end
  else

    stringified = begin
                    value.pretty_inspect
                  rescue RescuableException
                    nil
                  end

    unless String === stringified
      # Read the class name off of the singleton class to provide a default inspect.
      klass = (class << value; self; end).ancestors.first
      stringified = "#<#{klass}:0x#{value.__id__.to_s(16)}>"
    end
  

    colorized = Pry::Helpers::BaseHelpers.colorize_code(stringified.gsub(/#</, "%<#{nonce}"))

    # avoid colour-leak from CodeRay and any of the users' previous output
    olorized = colorized.sub(/(\n*)$/, "\e[0m\\1") if Pry.color

    Pry::Helpers::BaseHelpers.stagger_output("=> #{colorized.gsub(/%<(.*?)#{nonce}/, '#<\1')}", output)
    end
 end
