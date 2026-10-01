import sys, os
import win32com.client

path = sys.argv[1]
app = win32com.client.Dispatch('KWPP.Application')
try:
    pres = app.Presentations.Open(os.path.abspath(path), True, False, False)
except Exception:
    pres = app.Presentations.Open(os.path.abspath(path), True, False, True)
sc = pres.Slides.Count
shc = -1
txt = ''
try:
    shc = pres.Slides.Item(1).Shapes.Count
    for i in range(1, shc + 1):
        try:
            t = pres.Slides.Item(1).Shapes.Item(i).TextFrame.TextRange.Text
            if t:
                txt += t + ' | '
        except Exception:
            pass
except Exception:
    pass
pres.Close()
app.Quit()
print('REOPEN-OK slides=%d shapes=%d text=%s' % (sc, shc, txt[:120]))
