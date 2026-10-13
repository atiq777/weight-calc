import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(App(store: Store(prefs)));
}

// ───────────────────────── units ─────────────────────────

enum UT { w, c }

class Unit {
  final String key;
  final String name;
  final double f;
  final UT t;
  const Unit(this.key, this.name, this.f, this.t);
}

const List<Unit> kUnits = [
  Unit('kg', 'কেজি', 1000, UT.w),
  Unit('g', 'গ্রাম', 1, UT.w),
  Unit('ser', 'সের', 933.1, UT.w),
  Unit('mon', 'মণ', 37324, UT.w),
  Unit('lb', 'পাউন্ড', 453.592, UT.w),
  Unit('oz', 'আউন্স', 28.3495, UT.w),
  Unit('dz', 'ডজন', 12, UT.c),
  Unit('hali', 'হালি', 4, UT.c),
  Unit('pc', 'পিস', 1, UT.c),
];

const List<String> kMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
];

Unit unitOf(String k) => kUnits.firstWhere((u) => u.key == k, orElse: () => kUnits[0]);
List<Unit> unitsOfType(UT t) => kUnits.where((u) => u.t == t).toList();

// ───────────────────────── number helpers ─────────────────────────

const String _bd = '০১২৩৪৫৬৭৮৯';

String bn(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 48 && r <= 57) {
      b.write(_bd[r - 48]);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

String en(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x09E6 && r <= 0x09EF) {
      b.write(r - 0x09E6);
    } else if (r == 44 || r == 0x60C || r == 32) {
      continue;
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

double pn(String s) {
  final v = double.tryParse(en(s));
  if (v == null || v.isNaN || v.isInfinite) return 0;
  return v;
}

String fmt(double n, [int d = 2]) {
  if (n.isNaN || n.isInfinite) return '০';
  final neg = n < 0;
  final parts = n.abs().toStringAsFixed(d).split('.');
  var i = parts[0];
  final f = parts.length > 1 ? parts[1].replaceAll(RegExp(r'0+$'), '') : '';
  if (i.length > 3) {
    final rest = i.substring(0, i.length - 3);
    final last = i.substring(i.length - 3);
    final b = StringBuffer();
    for (var k = 0; k < rest.length; k++) {
      if (k > 0 && (rest.length - k) % 2 == 0) b.write(',');
      b.write(rest[k]);
    }
    i = '${b.toString()},$last';
  }
  final sign = neg ? '-' : '';
  final frac = f.isEmpty ? '' : '.$f';
  return bn('$sign$i$frac');
}

String uid() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

String dayLabel(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final n = DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(n.year, n.month, n.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'আজ';
  if (diff == 1) return 'গতকাল';
  final yr = d.year != n.year ? ' ${bn(d.year.toString())}' : '';
  return '${bn(d.day.toString())} ${kMonths[d.month - 1]}$yr';
}

// ───────────────────────── models ─────────────────────────

class Calc {
  int mode;
  String name, price, pu, q, qu, money, ru, dtype, dval;

  Calc({
    this.mode = 0,
    this.name = '',
    this.price = '',
    this.pu = 'kg',
    this.q = '',
    this.qu = 'g',
    this.money = '',
    this.ru = 'kg',
    this.dtype = 'p',
    this.dval = '',
  });

  factory Calc.fromJson(Map<String, dynamic> j) => Calc(
        mode: (j['mode'] as int?) ?? 0,
        name: (j['name'] as String?) ?? '',
        price: (j['price'] as String?) ?? '',
        pu: (j['pu'] as String?) ?? 'kg',
        q: (j['q'] as String?) ?? '',
        qu: (j['qu'] as String?) ?? 'g',
        money: (j['money'] as String?) ?? '',
        ru: (j['ru'] as String?) ?? 'kg',
        dtype: (j['dtype'] as String?) ?? 'p',
        dval: (j['dval'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'name': name,
        'price': price,
        'pu': pu,
        'q': q,
        'qu': qu,
        'money': money,
        'ru': ru,
        'dtype': dtype,
        'dval': dval,
      };

  void sync() {
    final t = unitOf(pu).t;
    if (unitOf(qu).t != t) qu = t == UT.w ? 'g' : 'pc';
    if (unitOf(ru).t != t) ru = t == UT.w ? 'kg' : 'pc';
  }
}

class Shop {
  String p, q, u;
  Shop({this.p = '', this.q = '', this.u = 'g'});
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        p: (j['p'] as String?) ?? '',
        q: (j['q'] as String?) ?? '',
        u: (j['u'] as String?) ?? 'g',
      );
  Map<String, dynamic> toJson() => {'p': p, 'q': q, 'u': u};
}

class Item {
  final String id, name, detail;
  final double total;
  Item(this.id, this.name, this.detail, this.total);
  factory Item.fromJson(Map<String, dynamic> j) => Item(
        (j['id'] as String?) ?? uid(),
        (j['name'] as String?) ?? '',
        (j['detail'] as String?) ?? '',
        ((j['total'] as num?) ?? 0).toDouble(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'detail': detail, 'total': total};
}

class Hist {
  final String id, name, detail, res;
  final int ts;
  final Map<String, dynamic> calc;
  Hist(this.id, this.ts, this.name, this.detail, this.res, this.calc);
  factory Hist.fromJson(Map<String, dynamic> j) => Hist(
        (j['id'] as String?) ?? uid(),
        (j['ts'] as int?) ?? 0,
        (j['name'] as String?) ?? '',
        (j['detail'] as String?) ?? '',
        (j['res'] as String?) ?? '',
        Map<String, dynamic>.from((j['calc'] as Map?) ?? {}),
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'ts': ts, 'name': name, 'detail': detail, 'res': res, 'calc': calc};
}

// ───────────────────────── store ─────────────────────────

class Store extends ChangeNotifier {
  final SharedPreferences prefs;
  List<Item> items = [];
  List<Hist> hist = [];
  String? theme;
  int tab = 0;
  Calc calc = Calc();
  Shop a = Shop();
  Shop b = Shop(u: 'kg');
  int calcRev = 0;

  Store(this.prefs) {
    _load();
  }

  void _load() {
    try {
      final s = prefs.getString('wohisab_v1');
      if (s == null) return;
      final j = jsonDecode(s) as Map<String, dynamic>;
      items = ((j['items'] as List?) ?? [])
          .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      hist = ((j['hist'] as List?) ?? [])
          .map((e) => Hist.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      theme = j['theme'] as String?;
      tab = (j['tab'] as int?) ?? 0;
      if (tab < 0 || tab > 3) tab = 0;
      if (j['calc'] != null) calc = Calc.fromJson(Map<String, dynamic>.from(j['calc'] as Map));
      if (j['a'] != null) a = Shop.fromJson(Map<String, dynamic>.from(j['a'] as Map));
      if (j['b'] != null) b = Shop.fromJson(Map<String, dynamic>.from(j['b'] as Map));
    } catch (_) {}
  }

  void save() {
    try {
      prefs.setString(
        'wohisab_v1',
        jsonEncode({
          'items': items.map((e) => e.toJson()).toList(),
          'hist': hist.map((e) => e.toJson()).toList(),
          'theme': theme,
          'tab': tab,
          'calc': calc.toJson(),
          'a': a.toJson(),
          'b': b.toJson(),
        }),
      );
    } catch (_) {}
  }

  void changed() {
    save();
    notifyListeners();
  }
}

// ───────────────────────── calculation ─────────────────────────

class Res {
  final int mode;
  final double gross, disc, total, per, base, qty, money;
  final UT type;
  const Res({
    required this.mode,
    this.gross = 0,
    this.disc = 0,
    this.total = 0,
    required this.per,
    this.base = 0,
    this.qty = 0,
    this.money = 0,
    required this.type,
  });
}

Res? compute(Calc c) {
  c.sync();
  final price = pn(c.price);
  if (!(price > 0)) return null;
  final pu = unitOf(c.pu);
  final per = price / pu.f;
  if (c.mode == 0) {
    final q = pn(c.q);
    if (!(q > 0)) return null;
    final gross = per * q * unitOf(c.qu).f;
    final dv = pn(c.dval);
    double disc = 0;
    if (dv > 0) {
      if (c.dtype == 'p') {
        disc = gross * (dv > 100 ? 100 : dv) / 100;
      } else {
        disc = dv > gross ? gross : dv;
      }
    }
    return Res(mode: 0, gross: gross, disc: disc, total: gross - disc, per: per, type: pu.t);
  }
  final m = pn(c.money);
  if (!(m > 0)) return null;
  final base = m / per;
  return Res(mode: 1, money: m, base: base, qty: base / unitOf(c.ru).f, per: per, type: pu.t);
}

class Summ {
  final String name, detail, res;
  final double total;
  const Summ(this.name, this.detail, this.res, this.total);
}

Summ? summaryOf(Calc c) {
  final r = compute(c);
  if (r == null) return null;
  final nm = c.name.trim().isEmpty ? 'জিনিস' : c.name.trim();
  final rate = '${fmt(pn(c.price))}৳ প্রতি ${unitOf(c.pu).name}';
  if (r.mode == 0) {
    final dd = r.disc > 0 ? ' · ছাড় ${fmt(r.disc)}৳' : '';
    final d = '${fmt(pn(c.q), 3)} ${unitOf(c.qu).name} · $rate$dd';
    return Summ(nm, d, '${fmt(r.total)} ৳', r.total);
  }
  return Summ(nm, '${fmt(r.money)}৳ · $rate', '${fmt(r.qty, 3)} ${unitOf(c.ru).name}', r.money);
}

class Rate {
  final double val;
  final UT t;
  final String unit;
  const Rate(this.val, this.t, this.unit);
}

Rate? shopRate(Shop s) {
  final p = pn(s.p);
  final q = pn(s.q);
  if (!(p > 0 && q > 0)) return null;
  final u = unitOf(s.u);
  final per = p / (q * u.f);
  return u.t == UT.w ? Rate(per * 1000, UT.w, 'কেজি') : Rate(per, UT.c, 'পিস');
}

String calcText(Calc c) {
  final s = summaryOf(c);
  if (s == null) return '';
  return '${s.name}\n${s.detail}\nহিসাব: ${s.res}';
}

double listTotal(Store s) => s.items.fold<double>(0, (a, b) => a + b.total);

String listText(Store s) {
  final lines = s.items.map((i) => '${i.name} — ${fmt(i.total)} ৳').join('\n');
  return 'বাজারের হিসাব\n$lines\nমোট: ${fmt(listTotal(s))} ৳';
}

String cmpText(Store s) {
  final a = shopRate(s.a);
  final b = shopRate(s.b);
  if (a == null || b == null || a.t != b.t) return '';
  final d = (a.val - b.val).abs();
  final verdict = d < 0.005
      ? 'দুই দোকানের দাম সমান'
      : '${a.val < b.val ? 'দোকান ক' : 'দোকান খ'}-তে প্রতি ${a.unit} ${fmt(d)} ৳ কম';
  return 'দাম তুলনা\nদোকান ক: ${fmt(a.val)} ৳ প্রতি ${a.unit}\nদোকান খ: ${fmt(b.val)} ৳ প্রতি ${b.unit}\n$verdict';
}

// ───────────────────────── ui helpers ─────────────────────────

void toast(BuildContext c, String m) {
  final s = ScaffoldMessenger.of(c);
  s.hideCurrentSnackBar();
  s.showSnackBar(SnackBar(
    content: Text(m),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1800),
  ));
}

Future<bool> confirmDlg(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('মুছুন')),
      ],
    ),
  );
  return r == true;
}

InputDecoration dec(String label, {String? hint, Widget? suffix}) => InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color okColor(BuildContext c) => isDark(c) ? const Color(0xFF6FD69B) : const Color(0xFF17703F);
Color okBg(BuildContext c) => isDark(c) ? const Color(0xFF16301F) : const Color(0xFFE3F3E9);

class NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String> onChanged;
  const NumField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.,]'))],
      decoration: dec(label, hint: hint),
    );
  }
}

class UnitField extends StatelessWidget {
  final String value;
  final List<Unit> options;
  final String prefix;
  final String label;
  final ValueChanged<String> onChanged;
  const UnitField({
    super.key,
    required this.value,
    required this.options,
    this.prefix = '',
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final u in options)
                  ListTile(
                    title: Text('$prefix${u.name}'),
                    trailing: u.key == value ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(u.key);
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: dec(label, suffix: const Icon(Icons.arrow_drop_down)),
        child: Text('$prefix${unitOf(value).name}', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, body;
  final VoidCallback onTap;
  const EmptyState({super.key, required this.title, required this.body, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          const SizedBox(height: 14),
          FilledButton(onPressed: onTap, child: const Text('হিসাব করুন')),
        ],
      ),
    );
  }
}

// ───────────────────────── app ─────────────────────────

class App extends StatelessWidget {
  final Store store;
  const App({super.key, required this.store});

  ThemeData _theme(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF1D5FD0), brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: b == Brightness.dark ? const Color(0xFF0F1216) : const Color(0xFFF4F5F7),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ওজন হিসাব',
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: store.theme == 'dark'
              ? ThemeMode.dark
              : store.theme == 'light'
                  ? ThemeMode.light
                  : ThemeMode.system,
          home: Home(store: store),
        );
      },
    );
  }
}

class Home extends StatelessWidget {
  final Store store;
  const Home({super.key, required this.store});

  void _share(BuildContext context) {
    final t = switch (store.tab) {
      0 => calcText(store.calc),
      1 => store.items.isEmpty ? '' : listText(store),
      2 => cmpText(store),
      _ => '',
    };
    if (t.isEmpty) {
      toast(context, 'শেয়ার করার মতো কিছু নেই');
      return;
    }
    Share.share(t);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('ওজন হিসাব', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'শেয়ার করুন',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _share(context),
          ),
          IconButton(
            tooltip: dark ? 'লাইট মোড' : 'ডার্ক মোড',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () {
              store.theme = dark ? 'light' : 'dark';
              store.changed();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: store.tab,
        children: [
          CalcPage(store: store),
          ListPage(store: store),
          ComparePage(store: store),
          HistoryPage(store: store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: store.tab,
        onDestinationSelected: (i) {
          store.tab = i;
          store.changed();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'হিসাব'),
          NavigationDestination(
              icon: Icon(Icons.checklist), selectedIcon: Icon(Icons.checklist_rtl), label: 'তালিকা'),
          NavigationDestination(
              icon: Icon(Icons.balance_outlined), selectedIcon: Icon(Icons.balance), label: 'তুলনা'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'ইতিহাস'),
        ],
      ),
    );
  }
}

// ───────────────────────── tab 1: calculate ─────────────────────────

class CalcPage extends StatefulWidget {
  final Store store;
  const CalcPage({super.key, required this.store});
  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  final nm = TextEditingController();
  final pr = TextEditingController();
  final q = TextEditingController();
  final mn = TextEditingController();
  final dv = TextEditingController();
  int _rev = 0;

  Store get s => widget.store;

  @override
  void initState() {
    super.initState();
    _fill();
    _rev = s.calcRev;
    s.addListener(_onStore);
  }

  void _fill() {
    final c = s.calc;
    nm.text = c.name;
    pr.text = c.price;
    q.text = c.q;
    mn.text = c.money;
    dv.text = c.dval;
  }

  void _onStore() {
    if (_rev != s.calcRev) {
      _rev = s.calcRev;
      _fill();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    s.removeListener(_onStore);
    nm.dispose();
    pr.dispose();
    q.dispose();
    mn.dispose();
    dv.dispose();
    super.dispose();
  }

  void _add() {
    final sm = summaryOf(s.calc);
    if (sm == null) {
      toast(context, 'আগে দাম আর পরিমাণ লিখুন');
      return;
    }
    s.items.add(Item(uid(), sm.name, sm.detail, sm.total));
    s.changed();
    toast(context, 'তালিকায় যোগ হয়েছে');
  }

  void _save() {
    final sm = summaryOf(s.calc);
    if (sm == null) {
      toast(context, 'আগে দাম আর পরিমাণ লিখুন');
      return;
    }
    s.hist.insert(0, Hist(uid(), DateTime.now().millisecondsSinceEpoch, sm.name, sm.detail, sm.res, s.calc.toJson()));
    if (s.hist.length > 200) s.hist = s.hist.sublist(0, 200);
    s.changed();
    toast(context, 'ইতিহাসে সেভ হয়েছে');
  }

  void _clear() {
    final o = s.calc;
    s.calc = Calc(mode: o.mode, pu: o.pu, qu: o.qu, ru: o.ru);
    s.calcRev++;
    s.changed();
  }

  Widget _result(Res? r, Calc c) {
    final cs = Theme.of(context).colorScheme;
    if (r == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Text('দাম আর পরিমাণ লিখলে হিসাব এখানে দেখাবে।',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
      );
    }
    final fg = cs.onPrimaryContainer;
    final rows = <Widget>[];
    if (r.mode == 0) {
      rows.add(Text('মোট দাম', style: TextStyle(color: fg, fontSize: 13)));
      rows.add(Text('${fmt(r.total)} ৳', style: TextStyle(color: fg, fontSize: 34, fontWeight: FontWeight.w600)));
      if (r.disc > 0) {
        rows.add(_line('ছাড়ের আগে', '${fmt(r.gross)} ৳', fg));
        rows.add(_line('ছাড়', '− ${fmt(r.disc)} ৳', fg));
      }
      final hint = r.type == UT.w
          ? '১০০ গ্রাম = ${fmt(r.per * 100)} ৳ · ১ কেজি = ${fmt(r.per * 1000)} ৳'
          : '১ পিস = ${fmt(r.per)} ৳ · ১ ডজন = ${fmt(r.per * 12)} ৳';
      rows.add(const SizedBox(height: 8));
      rows.add(Text(hint, style: TextStyle(color: fg, fontSize: 13)));
    } else {
      final keys = r.type == UT.w ? ['g', 'kg', 'ser', 'lb'] : ['pc', 'hali', 'dz'];
      final alt = keys
          .where((k) => k != c.ru)
          .map((k) => '${fmt(r.base / unitOf(k).f)} ${unitOf(k).name}')
          .join(' · ');
      rows.add(Text('${fmt(r.money)} ৳ এ পাবেন', style: TextStyle(color: fg, fontSize: 13)));
      rows.add(Text('${fmt(r.qty, 3)} ${unitOf(c.ru).name}',
          style: TextStyle(color: fg, fontSize: 34, fontWeight: FontWeight.w600)));
      rows.add(const SizedBox(height: 8));
      rows.add(Text(alt, style: TextStyle(color: fg, fontSize: 13)));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  Widget _line(String a, String b, Color fg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a, style: TextStyle(color: fg, fontSize: 14)),
            Text(b, style: TextStyle(color: fg, fontSize: 14)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = s.calc;
    c.sync();
    final r = compute(c);
    final cs = Theme.of(context).colorScheme;
    final t = unitOf(c.pu).t;
    const gap = SizedBox(height: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('ওজন থেকে টাকা')),
              ButtonSegment<int>(value: 1, label: Text('টাকা থেকে ওজন')),
            ],
            selected: {c.mode},
            onSelectionChanged: (v) {
              c.mode = v.first;
              s.save();
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nm,
          decoration: dec('জিনিসের নাম (ঐচ্ছিক)', hint: 'মসুর ডাল'),
          onChanged: (v) {
            c.name = v;
            s.save();
          },
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: NumField(
                controller: pr,
                label: 'জিনিসের দাম (টাকা)',
                hint: '১৪০',
                onChanged: (v) {
                  c.price = v;
                  s.save();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: UnitField(
                value: c.pu,
                options: kUnits,
                prefix: 'প্রতি ',
                label: 'একক',
                onChanged: (k) {
                  c.pu = k;
                  c.sync();
                  s.save();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        gap,
        if (c.mode == 0) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: NumField(
                  controller: q,
                  label: t == UT.w ? 'কত ওজন কিনবেন' : 'কত পিস কিনবেন',
                  hint: '৭৫০',
                  onChanged: (v) {
                    c.q = v;
                    s.save();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: UnitField(
                  value: c.qu,
                  options: unitsOfType(t),
                  label: 'একক',
                  onChanged: (k) {
                    c.qu = k;
                    s.save();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              initiallyExpanded: pn(c.dval) > 0,
              title: Text('ছাড় আছে?', style: TextStyle(color: cs.primary, fontSize: 14)),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: NumField(
                        controller: dv,
                        label: 'ছাড়ের পরিমাণ',
                        hint: '১০',
                        onChanged: (v) {
                          c.dval = v;
                          s.save();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<String>(value: 'p', label: Text('%')),
                        ButtonSegment<String>(value: 't', label: Text('৳')),
                      ],
                      selected: {c.dtype},
                      onSelectionChanged: (v) {
                        c.dtype = v.first;
                        s.save();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          NumField(
            controller: mn,
            label: 'কত টাকা আছে',
            hint: '১০০',
            onChanged: (v) {
              c.money = v;
              s.save();
              setState(() {});
            },
          ),
          gap,
          UnitField(
            value: c.ru,
            options: unitsOfType(t),
            label: 'কোন এককে দেখাবেন',
            onChanged: (k) {
              c.ru = k;
              s.save();
              setState(() {});
            },
          ),
          const SizedBox(height: 14),
        ],
        _result(r, c),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('তালিকায় যোগ'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('সেভ করুন'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _clear, child: const Text('পরিষ্কার করুন')),
      ],
    );
  }
}

// ───────────────────────── tab 2: list ─────────────────────────

class ListPage extends StatefulWidget {
  final Store store;
  const ListPage({super.key, required this.store});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final qn = TextEditingController();
  final qp = TextEditingController();

  Store get s => widget.store;

  @override
  void dispose() {
    qn.dispose();
    qp.dispose();
    super.dispose();
  }

  void _quickAdd() {
    final p = pn(qp.text);
    if (!(p > 0)) {
      toast(context, 'টাকার অঙ্ক লিখুন');
      return;
    }
    final name = qn.text.trim().isEmpty ? 'জিনিস' : qn.text.trim();
    s.items.add(Item(uid(), name, 'নিজে যোগ করা', p));
    qn.clear();
    qp.clear();
    s.changed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];

    if (s.items.isEmpty) {
      children.add(EmptyState(
        title: 'তালিকা এখনো ফাঁকা',
        body: 'হিসাব ট্যাব থেকে জিনিস যোগ করলে এখানে মোট বিল দেখাবে।',
        onTap: () {
          s.tab = 0;
          s.changed();
        },
      ));
    } else {
      for (final i in s.items) {
        children.add(Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(i.detail, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${fmt(i.total)} ৳', style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'মুছুন',
                icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
                onPressed: () {
                  s.items.removeWhere((x) => x.id == i.id);
                  s.changed();
                },
              ),
            ],
          ),
        ));
      }
    }

    children.add(const SizedBox(height: 14));
    children.add(Row(
      children: [
        Expanded(
          flex: 6,
          child: TextField(
            controller: qn,
            decoration: dec('জিনিসের নাম'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: NumField(controller: qp, label: 'টাকা', onChanged: (_) {}),
        ),
        const SizedBox(width: 8),
        IconButton.filled(tooltip: 'যোগ করুন', onPressed: _quickAdd, icon: const Icon(Icons.add)),
      ],
    ));

    if (s.items.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('মোট বিল', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            Text('${fmt(listTotal(s))} ৳', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          ],
        ),
      ));
      children.add(const SizedBox(height: 12));
      children.add(OutlinedButton.icon(
        onPressed: () => Share.share(listText(s)),
        icon: const Icon(Icons.ios_share),
        label: const Text('বিল শেয়ার করুন'),
      ));
      children.add(TextButton(
        onPressed: () async {
          final ok = await confirmDlg(context, 'সব জিনিস মুছে ফেলবেন?');
          if (ok) {
            s.items = [];
            s.changed();
          }
        },
        child: const Text('সব মুছুন'),
      ));
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: children);
  }
}

// ───────────────────────── tab 3: compare ─────────────────────────

class ComparePage extends StatefulWidget {
  final Store store;
  const ComparePage({super.key, required this.store});
  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  final pa = TextEditingController();
  final qa = TextEditingController();
  final pb = TextEditingController();
  final qb = TextEditingController();

  Store get s => widget.store;

  @override
  void initState() {
    super.initState();
    pa.text = s.a.p;
    qa.text = s.a.q;
    pb.text = s.b.p;
    qb.text = s.b.q;
  }

  @override
  void dispose() {
    pa.dispose();
    qa.dispose();
    pb.dispose();
    qb.dispose();
    super.dispose();
  }

  Widget _shop(String title, Shop sh, TextEditingController p, TextEditingController q, String hintP, String hintQ,
      bool cheap, Rate? r) {
    final cs = Theme.of(context).colorScheme;
    final ok = okColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cheap ? ok : cs.outlineVariant, width: cheap ? 1.5 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (cheap)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: okBg(context), borderRadius: BorderRadius.circular(8)),
                  child: Text('সস্তা', style: TextStyle(color: ok, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          NumField(
            controller: p,
            label: 'এত টাকা',
            hint: hintP,
            onChanged: (v) {
              sh.p = v;
              s.save();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: NumField(
                  controller: q,
                  label: 'এই পরিমাণের',
                  hint: hintQ,
                  onChanged: (v) {
                    sh.q = v;
                    s.save();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: UnitField(
                  value: sh.u,
                  options: kUnits,
                  label: 'একক',
                  onChanged: (k) {
                    sh.u = k;
                    s.save();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Text('প্রতি ${r.unit}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            Text('${fmt(r.val)} ৳', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = shopRate(s.a);
    final b = shopRate(s.b);

    String msg = 'দুই দোকানের দাম আর পরিমাণ লিখলে কোনটা সস্তা বোঝা যাবে।';
    bool good = false;
    bool aCheap = false;
    bool bCheap = false;
    if (a != null && b != null) {
      if (a.t != b.t) {
        msg = 'দুই দোকানে একই ধরনের একক দিন, দুটোই ওজন বা দুটোই সংখ্যা।';
      } else {
        final d = (a.val - b.val).abs();
        if (d < 0.005) {
          msg = 'দুই দোকানের দাম সমান।';
        } else {
          good = true;
          aCheap = a.val < b.val;
          bCheap = !aCheap;
          msg = '${aCheap ? 'দোকান ক' : 'দোকান খ'}-তে প্রতি ${a.unit} ${fmt(d)} ৳ কম।';
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _shop('দোকান ক', s.a, pa, qa, '৭০', '৫০০', aCheap, a),
        _shop('দোকান খ', s.b, pb, qb, '১৫০', '১', bCheap, b),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: good ? okBg(context) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(msg, style: TextStyle(color: good ? okColor(context) : cs.onSurfaceVariant, fontSize: 14)),
        ),
      ],
    );
  }
}

// ───────────────────────── tab 4: history ─────────────────────────

class HistoryPage extends StatelessWidget {
  final Store store;
  const HistoryPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = store;
    if (s.hist.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          EmptyState(
            title: 'ইতিহাস এখনো ফাঁকা',
            body: 'হিসাব ট্যাবে সেভ করুন চাপলে আগের হিসাব এখানে জমা থাকবে।',
            onTap: () {
              s.tab = 0;
              s.changed();
            },
          ),
        ],
      );
    }

    final children = <Widget>[];
    var last = '';
    for (final h in s.hist) {
      final l = dayLabel(h.ts);
      if (l != last) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Text(l, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ));
        last = l;
      }
      children.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(h.detail, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(h.res, style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              tooltip: 'আবার দেখুন',
              icon: Icon(Icons.replay, color: cs.onSurfaceVariant),
              onPressed: () {
                s.calc = Calc.fromJson(h.calc);
                s.calcRev++;
                s.tab = 0;
                s.changed();
              },
            ),
            IconButton(
              tooltip: 'মুছুন',
              icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
              onPressed: () {
                s.hist.removeWhere((x) => x.id == h.id);
                s.changed();
              },
            ),
          ],
        ),
      ));
    }
    children.add(TextButton(
      onPressed: () async {
        final ok = await confirmDlg(context, 'সব ইতিহাস মুছে ফেলবেন?');
        if (ok) {
          s.hist = [];
          s.changed();
        }
      },
      child: const Text('ইতিহাস মুছুন'),
    ));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: children);
  }
}
