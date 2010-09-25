#job job1:
#	read 	(k1:type,v1:type) from "/path/to/file.ext" 	using DataReaderClassName
#	map 	(k1:type,v1:type) to 	(k2:type,v2:type) 	using mapClassname 
#	reduce 	(k2:type,v2:type) to 	(k2:type,v2:type) 	using redClassname
#	write 	(k3:type,v3:type) to 	"/path/to/file.ext" 	using DataWriterClassName

class Abu
	def initialize(out)
		@out=out
	end
	
	def self.generate(out,&block)
		new(out).instance_eval(&block)
	end
	
	def job(name)
		@out << "\njob #{name}:\n"
		if block_given?
			yield
		end
		nil
	end

	def read(key, value, from, using)
		@out << "read (#{key},#{value}) from #{from} using #{using}" << "\n"
		nil
	end

	def map(key1, value1, key2, value2, using)
		@out << "map (#{key1},#{value1}) to [(#{key2},#{value2})] using #{using}" << "\n"
		nil
	end

	def reduce(key2, listOfvalue2, key3, value3, using)
		@out << "reduce (#{key2},#{listOfvalue2}) to (#{key3},#{value3}) using #{using}" << "\n"
		nil
	end

	def mapreduce(name)
		@out << "\nmapreduce #{name}:\n"
		if block_given?
			yield
		end
		nil
	end

	def exec(name,key1, value1, key3, value3)
		@out << "#{name} (#{key1},#{value1}) to (#{key3},#{value3})\n"
	end
	
	def write(key, value, to, using)
		@out << "write (#{key},#{value}) to #{to} using #{using}" << "\n"
		nil
	end
end
