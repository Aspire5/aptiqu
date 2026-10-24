import json
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

directory = Path(__file__).resolve().parent
repository = directory.parents[3]
font_path = repository / 'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Regular.ttf'
title_path = repository / 'assets/fonts/outfit/Outfit-SemiBold.ttf'
scale = 2
font = ImageFont.truetype(str(font_path), 16 * scale)
title = ImageFont.truetype(str(title_path), 16 * scale)
small = ImageFont.truetype(str(font_path), 11 * scale)


def wrap(draw, value, width):
    result = []
    for paragraph in value.split('\n'):
        if not paragraph:
            result.append('')
            continue
        current = ''
        for word in paragraph.split():
            candidate = f'{current} {word}'.strip()
            if current and draw.textlength(candidate, font=font) > width:
                result.append(current)
                current = word
            else:
                current = candidate
        result.append(current)
    return result


for filename, selected, output in [
    ('sample-2-openai-beginner.md', ['s1', 's4', 's8'], 'phone-preview-baseline.png'),
    ('sample-6-openai-beginner.md', ['s1', 's6', 's11'], 'phone-preview-revised.png'),
]:
    data = json.loads(re.search(r'```json\n([\s\S]*?)\n```', (directory / filename).read_text()).group(1))
    image = Image.new('RGB', (1000 * scale, 650 * scale), '#e9e8ef')
    draw = ImageDraw.Draw(image)
    draw.text((16 * scale, 12 * scale), 'Typography preview only · 320 px phones · 16 px approved reading font · not Flutter', font=small, fill='#4e4b59')
    for column, screen_id in enumerate(selected):
        screen = next(screen for screen in data['screens'] if screen['id'] == screen_id)
        left = (12 + column * 332) * scale
        draw.rounded_rectangle((left, 40 * scale, left + 320 * scale, 635 * scale), radius=18 * scale, fill='#f8f7fc')
        draw.text((left + 16 * scale, 58 * scale), f'AptiQu · {screen_id}', font=title, fill='#3d176c')
        lines = wrap(draw, screen['text'], 256 * scale)
        height = len(lines) * 24 * scale + 32 * scale
        draw.rounded_rectangle((left + 16 * scale, 96 * scale, left + 304 * scale, 96 * scale + height), radius=12 * scale, fill='#ffffff')
        cursor = 112 * scale
        for line in lines:
            draw.text((left + 32 * scale, cursor), line, font=font, fill='#1c1d29')
            cursor += 24 * scale
        if screen['kind'] == 'check':
            for option in screen['options']:
                draw.rounded_rectangle((left + 16 * scale, cursor + 8 * scale, left + 304 * scale, cursor + 56 * scale), radius=10 * scale, outline='#ddd9e8', width=scale, fill='#ffffff')
                draw.text((left + 30 * scale, cursor + 20 * scale), f"{option['id'].upper()}. {option['label']}", font=font, fill='#1c1d29')
                cursor += 60 * scale
        else:
            draw.rounded_rectangle((left + 16 * scale, cursor + 10 * scale, left + 304 * scale, cursor + 58 * scale), radius=10 * scale, fill='#6d28d9')
            draw.text((left + 108 * scale, cursor + 23 * scale), 'Continue', font=font, fill='#ffffff')
    image.save(directory / output)
    print(output)
