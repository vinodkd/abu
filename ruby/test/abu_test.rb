require '../src/abu.rb'

s1= Abu.script do
	job 'job3' do
		read 'LongWritable','Text','/path/to/file.ext', 'DataReaderClassName'
		exec 'mr1','LongWritable','Text','Text', 'IntWritable'
		write 'Text', 'IntWritable', '/path/to/file.ext', 'DataWriterClassName'
	end

	mapreduce 'mr1' do
		map 'LongWritable','Text','Text', 'IntWritable', 'Mapper'
		reduce 'k2','v2', 'k3','v3', 'reducer'
	end
end

s1.generate('./out')
s1.visualize('./out')