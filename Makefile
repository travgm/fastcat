AS = as
FLAGS = --64
LD = ld

all: cat

cat: cat.o
	$(LD) -o $@ $<

%.o: %.s
	$(AS) $(FLAGS) $< -o $@

clean:
	rm -rf *.o cat a.out
