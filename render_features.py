from playwright.sync_api import sync_playwright
import pathlib
src = pathlib.Path("/projects/sandbox/combo/falcon-os-features.html").resolve().as_uri()
out = "/projects/sandbox/combo/FALCON_OS_Features.pdf"
with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    pg = b.new_page()
    pg.goto(src, wait_until="networkidle")
    pg.emulate_media(media="print")
    pg.wait_for_timeout(1400)
    pg.pdf(path=out, prefer_css_page_size=True, print_background=True,
           margin={"top":"0","bottom":"0","left":"0","right":"0"})
    b.close()
print("WROTE", out)
