import os
import subprocess
from PIL import Image, ImageDraw

def main():
    root = r"D:\projects\shear_heaven_pet_spa"
    logo_svg = os.path.join(root, "assets", "images", "common", "logo.svg")
    html_path = os.path.join(root, "icon_render.html")
    master_png = os.path.join(root, "assets", "images", "common", "app_icon.png")

    html_content = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    width: 1024px;
    height: 1024px;
    background-color: #FFFFFF;
    display: flex;
    justify-content: center;
    align-items: center;
    overflow: hidden;
  }}
  img {{
    width: 760px;
    height: auto;
    max-height: 760px;
    object-fit: contain;
  }}
</style>
</head>
<body>
  <img src="{logo_svg.replace('\\', '/')}">
</body>
</html>
"""
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)

    edge_paths = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    ]
    browser = None
    for p in edge_paths:
        if os.path.exists(p):
            browser = p
            break

    if not browser:
        print("No browser found")
        return

    cmd = [
        browser,
        "--headless",
        "--disable-gpu",
        "--force-device-scale-factor=1",
        "--window-size=1024,1024",
        f"--screenshot={master_png}",
        f"file:///{html_path.replace('\\', '/')}"
    ]
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, check=True)

    if os.path.exists(html_path):
        os.remove(html_path)

    print(f"Master icon saved to {master_png}")
    im = Image.open(master_png).convert("RGBA")
    if im.size != (1024, 1024):
        im = im.crop((0, 0, 1024, 1024))
        im.save(master_png)

    # Create round version
    mask = Image.new('L', (1024, 1024), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, 1024, 1024), fill=255)
    round_im = Image.new('RGBA', (1024, 1024), (255, 255, 255, 0))
    round_im.paste(im, (0, 0), mask=mask)

    # Save to all mipmap directories
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    res_dir = os.path.join(root, "android", "app", "src", "main", "res")
    for folder, sz in sizes.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # Standard icon
        out_file = os.path.join(folder_path, "ic_launcher.png")
        resized = im.resize((sz, sz), Image.Resampling.LANCZOS)
        resized.save(out_file, "PNG")
        print(f"Generated {out_file} ({sz}x{sz})")

        # Round icon
        round_out_file = os.path.join(folder_path, "ic_launcher_round.png")
        round_resized = round_im.resize((sz, sz), Image.Resampling.LANCZOS)
        round_resized.save(round_out_file, "PNG")
        print(f"Generated {round_out_file} ({sz}x{sz})")

    # Also save 512x512 web icon
    web_icon = os.path.join(root, "android", "app", "src", "main", "ic_launcher-web.png")
    im.resize((512, 512), Image.Resampling.LANCZOS).save(web_icon, "PNG")
    print(f"Generated {web_icon} (512x512)")

if __name__ == "__main__":
    main()
