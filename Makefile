all: edge_detection

edge_detection: edge_detection.c functions.S
	gcc -lm -c functions.S
	gcc -lm -c edge_detection.c
	gcc -lm -o edge_detection edge_detection.o functions.o
	
clean:
	rm -f *~ *.o edge_detection *.swp
