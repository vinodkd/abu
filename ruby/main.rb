# simple abu runner

$:.<< File.join(File.dirname(__FILE__),'./lib')   #add lib directory to path. This way abu can be run in non-gem mode as well.

require "abu"

def main
    puts 'Abu: The hadoop scripting language, generator and visualizer'
    if ARGV.length < 2
      puts "Usage: <abu|jabu> script.abu outdir [gen|viz]+" 
      return 1
    end
    script = ARGV[0]
    outdir = ARGV[1]

    gen_needed = ARGV[2].downcase.eql? 'gen' if ARGV[2]
    gen_needed = ARGV[3].downcase.eql? 'gen' if ARGV[3] and !gen_needed

    viz_needed = ARGV[2].downcase.eql? 'viz' if ARGV[2]
    viz_needed = ARGV[3].downcase.eql? 'viz' if ARGV[3] and !viz_needed

    # puts "#{gen_needed}, #{viz_needed}"
    begin
      abu = Abu::Abu.new script, outdir
      abu.parse
      abu.generate if gen_needed
      abu.visualize if viz_needed
    rescue Exception => e
      puts "An error occured in processing #{script}: #{e}, \n\tDetails:#{e.backtrace[0]}"
    end
end
