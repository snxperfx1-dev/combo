from playwright.sync_api import sync_playwright
import pathlib
src = pathlib.Path("/projects/sandbox/combo/falcon-os-build-dossier.html").resolve().as_uri()
with sync_playwright() as p:
    b = p.chromium.launch(args=["--no-sandbox"])
    pg = b.new_page(viewport={"width":794,"height":1123}, device_scale_factor=1)
    pg.goto(src, wait_until="networkidle")
    pg.wait_for_timeout(1000)
    n = pg.eval_on_selector_all(".page", "els => els.length")
    for i in range(n):
        el = pg.query_selector_all(".page")[i]
        el.screenshot(path=f"/projects/sandbox/combo/_sec{i:02d}.png")
    print("sections:", n)
    b.close()
