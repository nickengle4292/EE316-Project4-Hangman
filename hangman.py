import sys
import pygame as pg
import pandas as pd
import random
import serial
import time
from collections import Counter

class Game:
    def __init__(self):
        pg.init()
        self.display = pg.display.set_mode((800, 600))
        self.mysurf = pg.Surface((800, 600)).convert()
        self.clock = pg.time.Clock()
        self.word = self.choose_word()
        self.letters = self.make_letters()
        self.attempts = 6
        self.done = False
        self.x = 400 - ((len(self.word) / 2) * 25)
        self.x_line = 400 - ((len(self.word) / 2) * 25)
        self.x_1 = 400 - ((len(self.word) / 2) * 25)
        self.i = 0
        self.data_to_send = ""
        self.guessed_char = ""
        self.run()

    def run(self):
        self.draw_lines()
        self.write_serial("New Game?                       06")
        while self.done == False:
            self.display.blit(self.mysurf, (0,0))
            pg.display.flip()
            self.clock.tick(60)
            self.char = self.read_serial()
            if self.char == "y":
                self.char = ""
                self.char = self.read_serial()
                print(self.char)
                if self.char in self.letters:
                    self.draw_word()
                    if self.attempts == 6:
                        self.und = self.make_serial()
                        self.und += "6"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                    if self.attempts == 5:
                        self.und = self.make_serial()
                        self.und += "5"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_head()
                    if self.attempts == 4:
                        self.und = self.make_serial()
                        self.und += "4"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_l_arm()
                    if self.attempts == 3:
                        self.und = self.make_serial()
                        self.und += "3"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_r_arm()
                    if self.attempts == 2:
                        self.und = self.make_serial()
                        self.und += "2"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_l_leg()
                    if self.attempts == 1:
                        self.und = self.make_serial()
                        self.und += "1"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_r_leg()
                    if self.attempts == 0:
                        self.und = self.make_serial()
                        self.und += "0"
                        self.data_to_send = self.list_to_string(self.und)
                        self.write_serial(self.data_to_send)
                        self.draw_body()
                if self.attempts <= 0:
                    self.game_done()

            elif self.char == "n":
                pg.quit()
                sys.exit()

    def list_to_string(self, und):
        str = ""
        for items in und:
            str += items
        return str

    def make_serial(self):
        length = len(self.word)
        self.und = []
        for i in range(length):
            if self.word[i] in self.guessed_char:
                self.und += self.word[i]
            else:
                self.und += "_"
        for i in range(32 - length):
            self.und += " "
        self.und += "0"
        return self.und

    def write_serial(self, data):
        ser = serial.Serial('COM3', 9600)
        ser.write(data.encode('utf-8'))
        ser.close()

    def read_serial(self):
        ser = serial.Serial('COM3', 9600)
        char = ser.read(1).decode('utf-8')
        ser.close()
        return char

    def draw_lines(self):
        pg.draw.circle(self.mysurf, (255,255,0), (400, 90), 25, 2)
        pg.draw.line(self.mysurf, (255,255,0), (400,65), (400, 25), 5)
        pg.draw.line(self.mysurf, (255, 255, 0), (400, 25), (500, 25), 5)
        pg.draw.line(self.mysurf, (255, 255, 0), (500, 25), (500, 200), 5)
        length = len(self.word)
        for i in range(length):
            pg.draw.line(self.mysurf, (255,0,0), (self.x_line, 430), (self.x_line + 18, 430), 5)
            self.x_line = self.x_line + 25

    def game_done(self):
        self.done = True
        self.write_serial("New Game?                       06")
        while self.done:
            self.char = self.read_serial()
            if self.char == "y":
                self.done = False
                self.__init__()
                self.run()
            elif self.char == "n":
                pg.quit()
                sys.exit()

    def choose_word(self):
        df = pd.read_excel('countries_list.xlsx')
        random_word = random.choice(df['Country'])
        print(random_word)
        return random_word

    def make_letters(self):
        letters = "abcdefghijklmnopqrstuvwxyz"
        self.charecter_count = Counter(self.word)
        space_count = self.charecter_count.get(' ', 0)
        if space_count > 0:
            for i in range(space_count-1):
                letters += ' '
        for char, count in self.charecter_count.items():
            if count > 1:
                for i in range(count-1):
                    letters += char
        return letters

    def draw_word(self):
        x = self.x
        if self.char in self.letters:
            if self.char in self.word:
                for i, char in enumerate(self.word):
                    if char == self.char:
                        font = pg.font.Font(None, 48)
                        display_word = self.char
                        text = font.render(display_word, True, (255, 0, 0))
                        index = self.word.index(self.char)
                        self.mysurf.blit(text, (x + (i * 25), 400))
                        self.letters = self.letters.replace(self.char, '', 1)
                        self.guessed_char += self.char
                        print(self.guessed_char)
                        if len(self.guessed_char) == len(self.word):
                            self.mysurf.blit(text, (x + (i * 25), 400))
                            self.game_done()
                self.i = i
            else:
                font = pg.font.Font(None, 48)
                display_word = ''.join(self.char)
                text = font.render(display_word, True, (255, 0, 0))
                self.mysurf.blit(text, (self.x_1, 500))
                self.attempts -= 1
                self.x_1 = self.x_1 + 25
                self.letters = self.letters.replace(self.char, '', 1)

    def draw_l_arm(self):
        pg.draw.line(self.mysurf, (255, 0, 0), (400, 125), (350, 200), 5)
    def draw_r_arm(self):
        pg.draw.line(self.mysurf, (255, 0, 0), (400, 125), (450, 200), 5)
    def draw_l_leg(self):
        pg.draw.line(self.mysurf, (255, 0, 0), (400, 200), (350, 250), 5)
    def draw_r_leg(self):
        pg.draw.line(self.mysurf, (255, 0, 0), (400, 200), (450, 250), 5)
    def draw_body(self):
        pg.draw.line(self.mysurf, (255, 0, 0), (400,200), (400, 75), 5)
    def draw_head(self):
        pg.draw.circle(self.mysurf, (255, 0, 0), (400, 75), 25)

if __name__ == "__main__":
    my_game = Game()
    my_game.run()
    