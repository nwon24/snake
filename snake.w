@*Introduction. This program is a simple terminal snake game
written in C.

The user is able to control the dimensions of the board
and the length of the snake through command-line arguments.
The default board size is $50$ units by $50$ units, with a
snake size of $4$. The traditional WASD keys are used
for controlling the snake.

The program uses the ncurses library for terminal input and output.
When compiling, make sure to add {\tt -lncurses} to the compiler flags.
(Also make sure you have installed the ncurses library.)

@ Here is the high-level overview of the program. We will fill
in the components as we go.
@c
@<Include files@>@;
@<Global variables@>@;
@<Function declarations@>@;
@<Function definitions@>@;

int main(int argc, char *argv[])
{
  @<Parse command line arguments@>@;
  @<Initialise the program@>@;
  @<Run the snake game@>@;
  return 0;
}
@*Initialising the ncurses library. Let's begin by doing a few
basic things to initialise our program. Before we forget,
we should include the ncurses library header file.
@<Include files@>=
#include <ncurses.h>

@ One of the first things we want to do in initialising the program
is initialising the terminal. To keep things tidy, we shall
create a function |init_term| to do all terminal initialisation.

We want to change the mode of the terminal to raw mode, so that
keypresses are passed to our program immediately. We also want
to stop keystrokes from being echoed, since that wouldn't really
make sense, and our reading of the keystrokes to be non-blocking,
so we can do other stuff while waiting for the user to type something.

@<Initialise the program@>=
init_term();

@ Thankfully for us, all the functions we need 
to set up the terminal are nicely packaged in the ncurses library.
Recall that we must begin with |initscr()|, or else nothing
will work. Note that we also call |refresh()| to clear the screen.
@<Function definitions@>=
void init_term(void)
{
  initscr();
  refresh();
  raw();
  halfdelay(2);
  timeout(0);
  noecho();
}
@ Let's add the function declaration before we forget.

If you are wondering why we are adding function declarations even
though all the functions will end up being in the same C file, it
is to obviate the need to pay attention to the order in which
the functions appear in the resulting file. With all function
prototypes at the top of the file, the function definitions
don't have to be written in dependency order.
@<Function declarations@>=
void init_term(void);

@ While we're at it we might as well write a function |fini_term|
that will be used at the end of our program to restore the
terminal back to its original state. We want this function
to be called on the program's exit, so we use the convenient function
|atexit| to make sure that no matter how our program terminates,
|fini_term| will be run. Otherwise,  users might experience
some strange behaviour in their terminals.
@<Function declarations@>=
void fini_term(void);
@ The only thing we need to do in |fini_term| is call |endwin()|; this
automatically fixes the terminal and restores it to its original condition.
@<Function definitions@>=
void fini_term(void)
{
  endwin();
}
@
@<Initialise...@>=
atexit(fini_term);
@*Representing the board.
We will represent the board as a two dimensional array of characters. For
simplicity, we will require that the board be a square.

The size of the board can change, if the user supplies a command-line
argument, but if no argument is given we need to have a default board
size. This could be any abitrary value. Let's make it $10$, since that's
likely to fit on the terminal.
@d DEFAULT_BOARD_WIDTH 10

@<Global variables@>=
char **board;

@ Turning to the unpleasant details of using |malloc| to dynamically
allocate space for |board|, we realise we have to declare a global
variable for the board size. Since it is a global variable, we can
initialise it to |DEFAULT_BOARD_WIDTH|.
@<Global variables@>=
int width = DEFAULT_BOARD_WIDTH;

@ Here is the function we will use to dynamically allocate the board.
@<Function declarations@>=
void init_board(void);
@
@<Function definitions@>=
void init_board(void)
{
  @<Allocate the rows of |board|@>@;
  @<Allocate the columns of |board|@>@;
}
@ Allocating the rows is fairly simple since each row is just the top
level in our two-dimensional array |board|. Thus a single call to |malloc|
suffices; however, as always with |malloc|, we have to check for a
bad return value. The chance of this happening is virtually zero, since
that would mean either the system really doesn't have any memory, or something
else has gone horribly wrong.
@<Allocate the rows...@>=
board = malloc(sizeof(char *) * width);
if (board == NULL) {
  @<Exit because |malloc| returned |NULL|@>@;
}

@ For the columns, we need a loop. In each iteration we also fill the board
with its initial values; this will be explained soon. Note that we actually
allocate one more than |width|, since we also need space for the terminating
NULL character that marks the end of a string in C. Of course, we could do
without this, but things get much more dangerous.
@<Allocate the columns...@>=
for (int i = 0; i < width; i++) {
  board[i] = malloc(width+1);
  if (board[i] == NULL) {
    @<Exit because |malloc| returned |NULL|@>@;
  }
  @<Fill current row of |board| with initial values@>@;
  board[width] = '\0';
}
@ We should never see this message on the screen, unless the user is deliberately
trying to crash the program but parsing an unreasonable width on the command
line.
@<Exit because |malloc| returned |NULL|@>=
fprintf(stderr, "FATAL ERROR: malloc returned NULL!");
exit(EXIT_FAILURE);

@ Filling the board with initial values just means we get |board| ready
for pritning on the screen.

We will define part of the snake to be a hash character, and the apple
to be a star. The rest of the board will just be dots.

Filling each row is fairly easy with |memset|.
@d SNAKE_CHAR '#'
@d APPLE_CHAR '*'
@d BOARD_CHAR '.'

@<Fill current row of |board| with initial values@>=
memset(board[i], BOARD_CHAR, width);

@ Don't forget to add |init_board()| to our initialisation sequence!
@<Initialise the program@>=
init_board();
@*Displaying the board.
Next up: showing the current board on the screen.  The eventual plan
of the program is actually quite simple: get a keystroke, if any, update
the snake's position in the board, and print the board again. Currently
we are tackling the last part of the plan, as it is the easiest.
@<Function declarations@>=
void display_board(void);
@ Since our board is represented internally by a two dimensional array
of characters, we can just print one row at a time. We just need to make
sure that before doing any printing, we reset ncurses's internal
coordinates to the origin so that board prints over itself each time,
giving the illustion of the snake moving. If we didn't, each iteration
of the board would print one after the other, making for a very confusing game.
users might even visit their doctor to check if they are having hallucinations.

Even though the name of the function is |display_board|, we also want to
print some other information, like instructions and the current score. We haven't
declared a global variable yet to hold the score; we'll do that immediately
following the function definition.

@<Function definitions@>=
void display_board(void)
{
  move(0, 0);
  for (int i = 0; i < width; i++) {
    printw("%s\n", board[i]);
  }
  printw("INSTRUCTIONS: wasd to move, q to quit\n");
  printw("Score: %d\n", score);
  refresh();
}
@ 
@<Global variables@>=
int score = 0;
@*The snake. Let's turn our attention to the snake. Since the length
of the snake will be increasing when it eats the apples, we will
represent it as a linked list of adjacent coordinates. This will make it easy
to add coordinates as the snake increases in length.

The structure of coordinates is easy to define. There are two fields, one
for the row and one for the column. They are zero-indexed, meaning they
can be used directly as indices into the |board| array.

@<Global variables@>=
struct coordinate {
  int x, y;
  struct coordinate *next;
};

@ When the snake moves, we don't actually need to move each segment, since
each segment, except for the first, simply needs to move into the position
of the next one. The first one needs to move in the direction the snake
is going. So all we need to do to make the snake move is move the last
coordinate of the linked list to the front.

To make this easy, let's declare two pointers, one for the head of
the snake and one for the tail of the snake.
@<Global variables@>=
struct coordinate *snake_tail;
struct coordinate *snake_head;

@ During the initialisation phase, we want to initialise the snake
linked list as well. To do this, we'll define a function |init_snake|.

We'll also need a default length for the snake, in case the user does not
supply a length. We'll make it $4$ (this means there's plently of
room for the snake to grow).
@d DEFAULT_SNAKE_LENGTH 4
@<Function declarations@>=
void init_snake(void);
@ The global variable |snake_length| will be the length of the snake; it
is initialised to |DEFAULT_SNAKE_LENGTH| and will only be changed
if the user supplies the appropriate command-line argument.
@<Global variables@>=
int snake_length = DEFAULT_SNAKE_LENGTH;

@ The function |init_snake()| is comprised of a few components. Firstly,
we want to allocate the |coordinate| structures and add them to
the linked list, initialising each structure with the proper
coordinate. To keep things simple, we'll have the snake
start in the top right-hand corner and moving to the right.
Secondly, we want to add the snake to the board by taking
each coordinate and putting a |SNAKE_CHAR| in the there in |board|.
To save a little time, we can do both things in the same loop.
@f new none
@<Function definitions@>=
void init_snake(void)
{
  @<Check if |snake_length| is greater than |width|; if it is, print error and exit@>@;
  for (int i = 0; i < snake_length; i++) {
    struct coordinate *new;

    @<Dynamically allocate |new|@>@;
    /* Top row */
    new->x = i;
    new->y = 0;
    new->next = NULL;
    @<Put coordinates of |new| into |board|@>@;
    if (i == 0) {
       /* First coordinate---this is the tail of the snake */
       snake_tail = new;
       snake_head = new;
    } else {
      snake_head->next = new;
      snake_head = snake_head->next;
    }
  }
}
@ If the user has specified a starting snake length that is greater
than the width of the board, we print and error and terminate. We could
figure out how to position the snake at the beginning if it is longer
than the width of the board, but that would complicate the loop. This way,
users are encouraged to enter sane values.
@<Check if |snake_length| is greater than |width|; if it is, print error and exit@>=
if (snake_length > width) {
  fprintf(stderr, "The snake length of %d is greater than the board width of %d. This isn't allowed!\n", snake_length, width);
  exit(EXIT_FAILURE);
}

@ We have the same responsibility as before when dynamically
allocating |new|---to check for |NULL| return from |malloc()|.
This could probably be improved by having an error message
specific to the function in which |malloc()| failed.
@<Dynamically allocate |new|@>=
new = malloc(sizeof(*new));
if (new == NULL) {
   @<Exit because |malloc| returned |NULL|@>@;
}

@ Setting the proper character in our two-dimensonal array |board| to
|SNAKE_CHAR| is simple because our |coordinate| structure has fields
that can be used directly as indices. Note that the |y| field is used
first because for two-dimensional arrays the first index specifies
the row.
@<Put coordinates...@>=
board[new->y][new->x] = SNAKE_CHAR;

@ Now we just need to add |init_snake()| to our initialisation procedure.
@<Initialise the program@>=
init_snake();

@*Moving the snake.
Since we have the data structures for our snake and the board,
we can move to actually moving the snake around. As mentioned before,
this is actually quite an efficient task because we only have
to move the tail of the snake to the front to simulate the snake
moving continuously.

Where that front is depends on in which direction the snake is
moving. For example, if the head of the snake was at $(2, 3)$ and
the snake was moving left, then we would have to move the tail
coordinate to $(2, 2)$, keeping everything else the same. Similarly,
if the snake was moving to the right, we would move the tail
coordinate to $(2, 4)$. The up and down motions are analogous too.

So the first thing we need to do is to define a global variable
that will hold the direction in which the snake is moving. Since
it is nice to use symbolic names rather than numerical constants,
we use enumerations in C.
@<Global variables@>=
enum snake_direction {
   LEFT,
   RIGHT,
   UP,
   DOWN
};
enum snake_direction direction = RIGHT;
@ Here is our |move_snake| function. Note that we're not
actually doing anything to the board; we're just manipulating
the linked list. Updating the |board| array will be done
in a separate function.

@<Function declarations@>=
void move_snake(void);
@ The rules of the game state that if the snake runs into itself
or off the board, the game is over. Hence in this function we
need to check for that. If the game is indeed over, we should
set a global variable indicating that this is the case, so the
next time we go to update the display, we can display the message
to the user that the game is over and exit. 
@<Global variables@>=
bool game_over = false;
@ Ok, after a somewhat lengthly preamble, here is the definition
of our |move_snake()| function.
@<Function definitions@>=
void move_snake(void)
{
  /* Coordinates of the new head of the snake */
  struct coordinate *newhead;

  newhead = snake_tail;
  /* This line will be explained soon! */
  old_tail = *snake_tail;
  snake_tail = snake_tail->next;
  *newhead = *snake_head;
  snake_head->next = newhead;
  snake_head = newhead;
  @<Set coordinates of |newhead|@>@;
  @<Check if snake has run off the board or into itself@>@;
}
@
@<Set coordinates of |newhead|@>=
switch (direction) {
case LEFT:
  newhead->x--;
  break;
case RIGHT:
  newhead->x++;
  break;
case UP:
  newhead->y--;
  break;
case DOWN:
  newhead->y++;
  break;
}
@ One line in the definition of |move_snake()| probabily flummoxed you:
why are we saving |snake_tail| in something called |old_tail|? The answer
is that when we update the board, we will need to clear the coordinates
|snake_tail| once held so that it no longer has |SNAKE_CHAR|, but rather
|BOARD_CHAR|. Thus we need to save the coordinates of the tail somewhere,
and that place will be a global variable called |old_tail|.
@<Global variables@>=
struct coordinate old_tail;
@ Checking if the snake has run off the board is fairly easy;
the harder one is checking if the snake has run into itself,
since we need to traverse the linked list and check all the coordinates.
@<Check if snake has run off the board or into itself@>=
if ((newhead->x < 0 || newhead->x >= width) || (newhead->y < 0 || newhead->y >= width)) {
  /* Snake has run off the board */
  game_over = true;
} else {
  struct coordinate *ptr; /* Temporary pointer */
  for (ptr = snake_tail; ptr != newhead; ptr = ptr->next) {
    if (ptr->x == newhead->x && ptr->y == newhead->y) {
      /* Snake has run into itself */
      game_over = true;
    }
  }
}

@ In the course of moving the snake around, the player might collect
an apple, which adds to the score. When the snake eats an apple,
it grows longer by one unit. This function does the necessary
checks to add another |coordinate| struct to the linked list.

We try to grow the snake in the opposite direction to where
it is moving. For example, if the tail of the snake is at $(2,3)$
and the snake is moving right, we will make $(2,2)$ part of
the snake too. If growing the snake in the opposite direction
to its movement causes it to go off the board, we take this
as game over. This adds a little bit of difficulty to the
game.
@<Function declarations@>=
void grow_snake(void);
@ 
@<Function definitions@>=
void grow_snake(void)
{
  struct coordinate *new;

  new = malloc(sizeof(*new));
  if (new == NULL) {
    @<Exit because...@>@;
  }
  *new = *snake_tail;
  switch (direction) {
  case LEFT:
    new->x++;
    break;
  case RIGHT:
    new->x--;
    break;
  case UP:
    new->y++;
    break;
  case DOWN:
    new->y--;
    break;
  }
  if ((new->x < 0 || new->x >= width) || ((new->y < 0 || new->y >= width)))
    game_over = true;
  new->next = snake_tail;
  snake_tail = new;
  board[snake_tail->y][snake_tail->x] = SNAKE_CHAR;
}
@ After we have caused the snake to move, we need to update
the |board| array. Most of the entries in |board| that have
|SNAKE_CHAR| can be left alone, we only need to change the one
with coordinates of |snake_tail|. Note that if the snake has
eaten an apple, this function
must be called before |grow_snake()| so tthat |snake_tail| still points
to the end of the tail that has to be moved.
@<Function declarations@>=
void update_board(void);
@
@<Function definitions@>=
void update_board(void)
{
  board[old_tail.y][old_tail.x] = BOARD_CHAR;
  board[snake_head->y][snake_head->x] = SNAKE_CHAR;
}

@* The apple. The last piece of the puzzle we need before putting
everything together is the apple. This part is simple; we just need
to generate a random coordinate.

Let's first declare the global variable.
@<Global variables@>=
struct coordinate apple;
@ Unfortunately for us, C doesn't have an inbuilt function to generate
a numer in a range. The C standard does have the function |rand()|, which
generates a random number between $0$ and |RAND_MAX|, so we can use
the modulo operator to get a number between $0$ and |width-1|, which is what
we want.

Note that the this method of generating a number in a range is not
exactly uniform, but it suffices for our purposes.
@<Function declarations@>=
void generate_apple(void);
@ 
@<Function definitions@>=
void generate_apple(void)
{
  apple.x = rand() % width;
  apple.y = rand() % width;
  board[apple.y][apple.x] = APPLE_CHAR;
}
@ We need to set a variable seed value so that each time the generated
points aren't going to be the same. We'll use, as is common, the current
time as the seed.
@<Initialise the program@>=
srand(time(NULL));
@*Putting it all together.
Finally we are ready to put everything we have done so far together
and create a working game. Now that all the pieces are in the place
the implementation of the central loop is actually fairly simple,
as will be seen.

@ Before going onto the main loop, let's look at parsing the
command line arguments, through which the user is able to
control the board size and initial size of the snake.

The two flags {\tt -w} and {\tt -l} control the board size
and size of the snake respectively. No other flags are recognised
for the moment.

Parsing the command line is always boring and difficult to
understand because of the intricacies of the |getopt()| function.
It is safe to skip this part of the program, but if you want
to know exactly how the following code works, refer to
the |getopt()| manual page (try typing in your terminal {\tt man 3 getopt}).

@<Parse command line arguments@>=
int c; /* Option character */
while ((c = getopt(argc, argv, ":hw:l:")) > 0) {
  switch (c) {
  case 'h':
    usage();
    break;
  case 'w':
    width = atoi(optarg);
    if (width == 0) {
      fprintf(stderr, "Bad argument to -w flag.\n");
      exit(EXIT_FAILURE);
    }
    break;
  case 'l':
    snake_length = atoi(optarg);
    if (snake_length == 0) {
      fprintf(stderr, "Bad argument to -l flag.\n");
      exit(EXIT_FAILURE);
    }
    break;
  case ':':
    fprintf(stderr, "Missing argument to -%c\n", optopt);
    exit(EXIT_FAILURE);
    break;
  case '?':
    fprintf(stderr, "Unrecognised command line option -%c\n", optopt);
    exit(EXIT_FAILURE);
    break;
  }
}
@ In the above code we have used a function |usage()| to print help;
let's quickly define it here so we can move onto the real fruit
of our efforts.
@<Function declarations@>=
void usage(void);
@ 
@<Function definitions@>=
void usage(void)
{
  fprintf(stderr, "USAGE: snake [OPTION]\n");
  fprintf(stderr, "    Options:\n");
  fprintf(stderr, "      -w\tSpecify width of board\n");
  fprintf(stderr, "      -l\tSpecify starting length of snake\n");
  fprintf(stderr, "      -l\tPrint this help and exit\n");
  exit(EXIT_SUCCESS);
}

@ Finally, here it is: the core loop. After everything we have done, this
loop should be fairly easy to understand.
@d QUIT_CHAR 'q'
@d LEFT_CHAR 'a'
@d DOWN_CHAR 's'
@d RIGHT_CHAR 'd'
@d UP_CHAR 'w'

@<Run the snake game@>=
/* The keystrokes of the user */
int k;
generate_apple();
while ((k = getch()) != QUIT_CHAR) {
  /* This actually makes everything appear on the terminal! */
  refresh();
  display_board();
  @<Change direction of snake depending on value of keystroke@>@;
  move_snake();
  if (game_over == true) {
    @<Print game over message and exit@>@;
  }
  update_board();
  if (snake_head->x == apple.x && snake_head->y == apple.y) {
    score++;
    grow_snake();
    generate_apple();
  }
}
@
@<Change direction of snake depending on value of keystroke@>=
switch (k) {
case LEFT_CHAR:
  direction = LEFT;
  break;
case RIGHT_CHAR:
  direction = RIGHT;
  break;
case DOWN_CHAR:
  direction = DOWN;
  break;
case UP_CHAR:
  direction = UP;
  break;
}
@ Sympathy for losing the game is not needed.

This is a somewhat cumbersome method of exiting
the program when the game is over, but simply
using |printw()| wouldn't work since calling |endwin()|
immediately clears the screen. Using |printf()|
after |endwin()| means the line is printed by
itself on the user's terminal.
@<Print game over message and exit@>=
endwin();
printf("GAME OVER. Final score: %d\n", score);
return EXIT_SUCCESS;

@*Include files. Throughout the entire program we have just
assumed that the facilities of the C standard library were present.
Now we need to include all the standard library header files to
make the compiler happy. The reason this is last because this
is hardly interesting.
@<Include files@>=
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <time.h>
@*Index.