NAME = snake
PDF = ${NAME}.pdf
W = ${NAME}.w
TEX = ${NAME}.tex

all: $(NAME) $(PDF)

$(NAME): $(W)
	ctangle $<
	gcc ${NAME}.c -o $@ -Wall -Wextra -O2 -ggdb -lncurses
$(PDF): $(W)
	cweave $<
	pdftex $(TEX)
clean:
	rm $(TEX) $(PDF)
