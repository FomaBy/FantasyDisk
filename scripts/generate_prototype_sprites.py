from pathlib import Path

from PIL import Image, ImageDraw


OUT = Path("assets/sprites")


def save(path, size, draw_fn):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_fn(draw)
    img.save(OUT / path)


def poly(draw, points, fill, outline, width=4):
    draw.polygon(points, fill=fill)
    draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def player_berserk(draw):
    draw.ellipse((25, 22, 71, 68), fill="#4da3ff", outline="#10263f", width=5)
    poly(draw, [(48, 14), (58, 36), (48, 47), (38, 36)], "#ffd84d", "#10263f", 4)
    poly(draw, [(25, 68), (48, 55), (71, 68), (61, 84), (48, 77), (35, 84)], "#266fb5", "#10263f", 4)
    poly(draw, [(70, 18), (80, 27), (45, 62), (36, 53)], "#e6eef7", "#10263f", 4)


def player_ranger(draw):
    draw.ellipse((26, 23, 70, 67), fill="#36d06b", outline="#123620", width=5)
    draw.arc((24, 8, 72, 62), 205, 35, fill="#f5d06a", width=7)
    poly(draw, [(30, 64), (48, 54), (66, 64), (60, 82), (48, 75), (36, 82)], "#1f8a4a", "#123620", 4)
    poly(draw, [(62, 30), (79, 22), (72, 39)], "#f4f0df", "#123620", 3)


def player_summoner(draw):
    draw.ellipse((26, 23, 70, 67), fill="#b277ff", outline="#281640", width=5)
    poly(draw, [(24, 65), (48, 53), (72, 65), (64, 84), (48, 75), (32, 84)], "#6b35b5", "#281640", 4)
    draw.ellipse((62, 16, 80, 34), fill="#fff0a6", outline="#281640", width=4)
    draw.line((64, 32, 53, 46), fill="#fff0a6", width=6)
    draw.arc((34, 20, 62, 48), 200, 340, fill="#fff0a6", width=5)


def player_dark_mage(draw):
    draw.ellipse((26, 22, 70, 66), fill="#4b2d83", outline="#160b2a", width=5)
    poly(draw, [(18, 70), (48, 48), (78, 70), (67, 88), (48, 78), (29, 88)], "#24143f", "#160b2a", 5)
    poly(draw, [(28, 20), (48, 6), (68, 20), (60, 35), (48, 29), (36, 35)], "#9d5cff", "#160b2a", 4)
    draw.ellipse((34, 34, 43, 43), fill="#e6fbff")
    draw.ellipse((53, 34, 62, 43), fill="#e6fbff")
    draw.ellipse((61, 55, 82, 76), fill="#62f3ff", outline="#160b2a", width=4)
    draw.arc((28, 50, 68, 79), 15, 165, fill="#62f3ff", width=5)


def player_guitarist(draw):
    draw.ellipse((25, 21, 71, 67), fill="#ffd24d", outline="#33210a", width=5)
    poly(draw, [(22, 68), (48, 52), (74, 68), (64, 88), (48, 78), (32, 88)], "#ef4f8c", "#33210a", 5)
    draw.line((24, 18, 72, 18), fill="#33210a", width=5)
    draw.arc((25, 5, 71, 37), 180, 360, fill="#33210a", width=5)
    poly(draw, [(59, 45), (80, 58), (69, 76), (48, 62)], "#21d5c8", "#33210a", 4)
    draw.line((43, 60, 80, 26), fill="#f7f2db", width=7)
    draw.line((43, 60, 80, 26), fill="#33210a", width=2)


def weapon_dark_book(draw):
    poly(draw, [(18, 18), (46, 10), (78, 23), (70, 76), (39, 86), (12, 70)], "#382064", "#130820", 5)
    draw.line((45, 12, 38, 84), fill="#8e58ff", width=4)
    draw.ellipse((43, 39, 59, 55), fill="#62f3ff", outline="#130820", width=3)
    draw.arc((24, 28, 66, 70), 215, 330, fill="#d8bdff", width=4)


def weapon_cursed_skull(draw):
    draw.ellipse((21, 16, 75, 72), fill="#f3e9d1", outline="#271629", width=5)
    draw.rectangle((34, 61, 62, 83), fill="#f3e9d1", outline="#271629", width=4)
    draw.ellipse((33, 36, 44, 48), fill="#7f27ff")
    draw.ellipse((53, 36, 64, 48), fill="#7f27ff")
    draw.arc((35, 53, 62, 72), 0, 180, fill="#271629", width=4)
    draw.arc((15, 10, 83, 78), 210, 315, fill="#b850ff", width=5)


def weapon_dark_wand(draw):
    draw.line((20, 78, 73, 25), fill="#1a0f2a", width=13)
    draw.line((20, 78, 73, 25), fill="#61efff", width=6)
    draw.ellipse((61, 13, 86, 38), fill="#9d5cff", outline="#1a0f2a", width=5)
    draw.line((56, 42, 82, 16), fill="#f8f0ff", width=3)


def weapon_electric_guitar(draw):
    poly(draw, [(18, 50), (31, 32), (52, 38), (68, 27), (83, 41), (66, 59), (77, 78), (52, 79), (38, 65)], "#21d5c8", "#102b2b", 5)
    draw.line((54, 42, 88, 8), fill="#f7f2db", width=8)
    draw.line((54, 42, 88, 8), fill="#102b2b", width=2)
    draw.arc((15, 18, 88, 86), 210, 330, fill="#fff36b", width=5)


def weapon_bass_guitar(draw):
    poly(draw, [(20, 48), (35, 28), (58, 38), (71, 30), (82, 48), (68, 68), (45, 70), (31, 60)], "#ffc247", "#392411", 5)
    draw.line((52, 42, 86, 9), fill="#f8f1d1", width=9)
    draw.line((52, 42, 86, 9), fill="#392411", width=2)
    draw.arc((12, 18, 88, 86), 180, 360, fill="#ff6c9f", width=5)


def weapon_sound_amp(draw):
    draw.rounded_rectangle((20, 20, 78, 78), radius=8, fill="#2d2d40", outline="#11111c", width=5)
    draw.ellipse((33, 31, 65, 63), fill="#ff4f91", outline="#11111c", width=4)
    draw.ellipse((42, 40, 56, 54), fill="#ffe36b", outline="#11111c", width=3)
    draw.rectangle((29, 67, 69, 73), fill="#6cecff")
    draw.arc((10, 10, 88, 88), 210, 330, fill="#6cecff", width=5)


def enemy_melee(draw):
    poly(draw, [(40, 8), (69, 28), (58, 68), (22, 68), (11, 28)], "#ee4048", "#401014", 5)
    draw.ellipse((25, 30, 35, 40), fill="#fff4c4")
    draw.ellipse((45, 30, 55, 40), fill="#fff4c4")


def enemy_shooter(draw):
    poly(draw, [(40, 9), (65, 23), (65, 57), (40, 71), (15, 57), (15, 23)], "#9b56ff", "#25113f", 5)
    draw.ellipse((27, 27, 53, 53), fill="#ffd84d", outline="#25113f", width=4)
    poly(draw, [(55, 18), (68, 8), (63, 26)], "#ffd84d", "#25113f", 3)


def enemy_bruiser(draw):
    draw.ellipse((12, 8, 84, 89), fill="#f07a29", outline="#43200d", width=6)
    draw.line((31, 40, 42, 34), fill="#43200d", width=5)
    draw.line((65, 40, 54, 34), fill="#43200d", width=5)
    draw.arc((33, 52, 63, 75), 25, 155, fill="#43200d", width=5)


def enemy_runner(draw):
    poly(draw, [(40, 7), (64, 40), (40, 73), (16, 40)], "#36d06b", "#123620", 5)
    draw.line((20, 55, 5, 68), fill="#123620", width=5)
    draw.line((60, 55, 75, 68), fill="#123620", width=5)
    draw.ellipse((32, 29, 48, 45), fill="#fff4c4")


def boss_warden(draw):
    poly(draw, [(80, 8), (131, 35), (143, 93), (112, 145), (48, 145), (17, 93), (29, 35)], "#2b243f", "#f0c85b", 8)
    poly(draw, [(80, 22), (103, 60), (80, 81), (57, 60)], "#e05050", "#f0c85b", 5)
    draw.ellipse((45, 78, 65, 98), fill="#fff0a6")
    draw.ellipse((95, 78, 115, 98), fill="#fff0a6")
    draw.arc((52, 100, 108, 137), 25, 155, fill="#f0c85b", width=7)
    for line in [(27, 31, 8, 16), (133, 31, 152, 16), (28, 107, 8, 128), (132, 107, 152, 128)]:
        draw.line(line, fill="#f0c85b", width=7)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "characters").mkdir(parents=True, exist_ok=True)
    (OUT / "weapons").mkdir(parents=True, exist_ok=True)
    save("player_berserk.png", (96, 96), player_berserk)
    save("player_ranger.png", (96, 96), player_ranger)
    save("player_summoner.png", (96, 96), player_summoner)
    save("characters/dark_mage.png", (96, 96), player_dark_mage)
    save("characters/guitarist.png", (96, 96), player_guitarist)
    save("weapons/dark_book.png", (96, 96), weapon_dark_book)
    save("weapons/cursed_skull.png", (96, 96), weapon_cursed_skull)
    save("weapons/dark_wand.png", (96, 96), weapon_dark_wand)
    save("weapons/electric_guitar.png", (96, 96), weapon_electric_guitar)
    save("weapons/bass_guitar.png", (96, 96), weapon_bass_guitar)
    save("weapons/sound_amp.png", (96, 96), weapon_sound_amp)
    save("enemy_melee.png", (80, 80), enemy_melee)
    save("enemy_shooter.png", (80, 80), enemy_shooter)
    save("enemy_bruiser.png", (96, 96), enemy_bruiser)
    save("enemy_runner.png", (80, 80), enemy_runner)
    save("boss_warden.png", (160, 160), boss_warden)


if __name__ == "__main__":
    main()
