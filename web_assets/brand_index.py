"""Patch the Flutter-generated web/index.html with app branding.
Robust string edits (run by the deploy workflow after `flutter create`)."""
import re

PATH = "web/index.html"
html = open(PATH, encoding="utf-8").read()

html = re.sub(r"<title>.*?</title>",
              "<title>피드필터 – YouTube 카테고리</title>", html, flags=re.S)
html = re.sub(r'<meta name="apple-mobile-web-app-title" content="[^"]*">',
              '<meta name="apple-mobile-web-app-title" content="피드필터">', html)
html = re.sub(r'<meta name="description" content="[^"]*">',
              '<meta name="description" content="구독 피드를 카테고리로 걸러 보는 YouTube 필터">',
              html)

inject = (
    '<link rel="icon" type="image/svg+xml" href="icon.svg"/>\n'
    '  <link rel="apple-touch-icon" href="apple-touch-icon.png"/>\n'
    '  <meta name="theme-color" content="#E01E1E"/>\n  '
)
if "icon.svg" not in html:
    png = '<link rel="icon" type="image/png" href="favicon.png"/>'
    if png in html:
        html = html.replace(png, png + "\n  " + inject)
    else:
        html = html.replace("</head>", inject + "</head>")

open(PATH, "w", encoding="utf-8").write(html)
print("branding injected into", PATH)
