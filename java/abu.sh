# abu.sh: poor man's build file for Abu. Will be replaced with a true build file when the code gets larger.
# Right now this serves the purpose.
# This needs some cygwin or msys on windows and bash on Linux.

case $1 in
	build)
		javac -d ./build -cp ./lib/parboiled4j-0.9.8.2.jar:./build ./src/org/vinodkd/abu/*.java
		;;
	clean)
		rm -rf build/*
		;;
	run)
		java -cp ./lib/parboiled4j-0.9.8.2.jar:./build org.vinodkd.abu.AbuParser $2
		;;
	*)
		echo "abu.sh: a poor man's build system for Abu."
		echo "Usage:"
		echo "	abu.sh build 		- to build the code"
		echo "	abu.sh clean 		- to clean out a previous build"
		echo "	abu.sh run <script.abu>	- to run a script"
		;;
esac