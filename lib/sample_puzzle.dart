/// Demo puzzle (generator seed "7b") in JSON v1, full form.
const String samplePuzzleJson = '''
{
  "version": 1, "id": "practice-7b", "size": 7, "direction": "rtl",
  "grid": ["####ش#ب","####ورد","##ف#ق#ر","#اربيل#","##ع##ن#","##و##د#","صين#هند"],
  "numbers": [[0,4,1],[0,6,2],[1,4,3],[2,2,4],[3,1,5],[3,5,6],[6,0,7],[6,4,8]],
  "entries": [
    {"number":3,"dir":"across","row":1,"col":4,"length":3,"answer":"ورد","display":"ورد","clue":"زهر يُهدى رمزاً للمحبة"},
    {"number":5,"dir":"across","row":3,"col":1,"length":5,"answer":"اربيل","display":"أربيل","clue":"مركز إقليم كردستان العراق"},
    {"number":7,"dir":"across","row":6,"col":0,"length":3,"answer":"صين","display":"الصين","clue":"بلد السور العظيم"},
    {"number":8,"dir":"across","row":6,"col":4,"length":3,"answer":"هند","display":"الهند","clue":"بلد تاج محل"},
    {"number":1,"dir":"down","row":0,"col":4,"length":4,"answer":"شوقي","display":"أحمد شوقي","clue":"أمير الشعراء"},
    {"number":2,"dir":"down","row":0,"col":6,"length":3,"answer":"بدر","display":"بدر","clue":"أول غزوة كبرى في الإسلام"},
    {"number":4,"dir":"down","row":2,"col":2,"length":5,"answer":"فرعون","display":"فرعون","clue":"لقب ملوك مصر القديمة"},
    {"number":6,"dir":"down","row":3,"col":5,"length":4,"answer":"لندن","display":"لندن","clue":"عاصمة بريطانيا"}
  ]
}
''';
