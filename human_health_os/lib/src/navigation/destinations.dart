/// Destinations. Primary navigation is Today, Timeline, Labs (v0.32 kernel)
/// and Medications (F008). The other areas from v0.27 doc 209 are reachable
/// as a secondary "More areas" group (conflict C-8). Every listed area opens
/// a working screen (U034): an area with nothing to offer yet, such as
/// Compare, is not listed until it is built.
library;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';

enum DestinationId {
  today,
  timeline,
  labs,
  medications,
  nutrition,
  activity,
  conditions,
  preventive,
  documents,
  // Compare is not listed until it compares something (U034): F011 has no
  // compare engine yet, and the derived values are not a comparison.
  learn,
}

class Destination {
  const Destination({
    required this.id,
    required this.en,
    required this.tr,
    required this.icon,
    required this.selectedIcon,
    required this.purposeEn,
    required this.purposeTr,
    required this.plannedForge,
    required this.principleEn,
    required this.principleTr,
    required this.canDoEn,
    required this.canDoTr,
    this.emptyStateEn,
    this.emptyStateTr,
  });

  final DestinationId id;
  final String en;
  final String tr;
  final IconData icon;
  final IconData selectedIcon;
  final String purposeEn;
  final String purposeTr;

  /// Ladder Forge(s) that deliver the area's stated purpose (D-011, D-013);
  /// null only when that purpose is fully built.
  final String? plannedForge;

  /// One invariant this area must respect, shown so the empty state still teaches.
  final String principleEn;
  final String principleTr;

  /// One concrete sentence: what a person can do in this area (U031).
  final String canDoEn;
  final String canDoTr;

  /// What the unbuilt view truthfully says instead of "No records yet" when
  /// records of its kind can already exist elsewhere (e.g. Timeline, while
  /// Today saves weights). Null = "No records yet" is true for this area.
  final String? emptyStateEn;
  final String? emptyStateTr;

  bool get isPrimary => kPrimaryDestinations.contains(id);

  String label(AppLang lang) => lang == AppLang.tr ? tr : en;
  String purpose(AppLang lang) => lang == AppLang.tr ? purposeTr : purposeEn;
  String principle(AppLang lang) =>
      lang == AppLang.tr ? principleTr : principleEn;
  String canDo(AppLang lang) => lang == AppLang.tr ? canDoTr : canDoEn;
  String? emptyState(AppLang lang) =>
      lang == AppLang.tr ? emptyStateTr : emptyStateEn;
}

/// The F001 primary destinations (v0.32 kernel): the only first-level items
/// in both the compact bar and the rail.
const List<DestinationId> kPrimaryDestinations = [
  DestinationId.today,
  DestinationId.timeline,
  DestinationId.labs,
  // Built in F008.
  DestinationId.medications,
];

const List<Destination> destinations = [
  Destination(
    id: DestinationId.today,
    en: 'Today',
    tr: 'Bugün',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
    purposeEn: 'Your day at a glance: check-ins, missions and what changed.',
    purposeTr: 'Günün bir bakışta: kontroller, görevler ve neyin değiştiği.',
    plannedForge: 'Forge F007 · F011',
    principleEn: 'A mission is a plan. Only a logged completion counts.',
    principleTr: 'Görev bir plandır. Yalnız kaydedilen tamamlanma sayılır.',
    canDoEn: 'Save your weight, a measurement, last night\'s sleep or how you feel right now.',
    canDoTr: 'Kilonu, bir ölçümü, dün geceki uykunu ya da şu an nasıl hissettiğini kaydet.',
  ),
  Destination(
    id: DestinationId.timeline,
    en: 'Timeline',
    tr: 'Zaman çizelgesi',
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline,
    purposeEn: 'Every record on one timeline, with its source and corrections.',
    purposeTr: 'Her kayıt, kaynağı ve düzeltmeleriyle tek zaman çizelgesinde.',
    // Built in F003 for every record kind that exists (body weight); Labs
    // results join it in F004.
    plannedForge: null,
    principleEn: 'A correction adds a new version; the old one stays visible in history.',
    principleTr:
        'Düzeltme yeni bir sürüm ekler; eskisi geçmişte görünür kalır.',
    canDoEn:
        'Open any record to see where it came from, correct it or hide it.',
    canDoTr: 'Bir kaydı aç; nereden geldiğini gör, düzelt ya da gizle.',
  ),
  Destination(
    id: DestinationId.labs,
    en: 'Labs',
    tr: 'Tahliller',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
    purposeEn: 'Lab results as the report printed them: value, unit, specimen, the lab’s flag and its own reference range.',
    purposeTr: 'Tahlil sonuçları raporda yazdığı gibi: değer, birim, numune, laboratuvarın işareti ve kendi referans aralığı.',
    // Built in F004 (manual entry as printed). Interpretation is not part of
    // this purpose; it is planned with the deterministic engines (F011).
    plannedForge: null,
    // Plain words for: reference interval ≠ optimal target ≠ decision limit;
    // outside reference ≠ critical: not automatically critical, never "never
    // an emergency" (a critical value is outside the range too; R023).
    principleEn: 'A reference range describes a reference group; it is not necessarily the best value for you, and not a limit for a medical decision. A result outside the range is not, by itself, an emergency.',
    principleTr: 'Referans aralığı bir referans grubunu tanımlar; senin için en iyi değer olmak zorunda değildir, tıbbi bir karar sınırı da değildir. Aralığın dışında kalan bir sonuç tek başına acil durum demek değildir.',
    canDoEn: 'Type a result from your lab report, then correct it later if you typed it wrong.',
    canDoTr:
        'Tahlil raporundaki bir sonucu yaz; yanlış yazdıysan sonra düzelt.',
  ),
  Destination(
    id: DestinationId.medications,
    en: 'Medications',
    tr: 'İlaçlar',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication,
    purposeEn: 'Medicines and supplements: products, ingredients, plans and actual intake.',
    purposeTr:
        'İlaç ve takviyeler: ürünler, etken maddeler, planlar ve gerçek alım.',
    // Built in F008: products, plans and recorded doses kept apart.
    plannedForge: null,
    principleEn: 'A prescription or reminder is not an intake. "No interaction found" is not "safe".',
    principleTr: 'Reçete ya da hatırlatma alım değildir. "Etkileşim bulunamadı", "güvenli" demek değildir.',
    canDoEn: 'Add a medicine or supplement, write how it is meant to be taken, and note each dose you took or skipped.',
    canDoTr: 'Bir ilaç ya da takviye ekle, nasıl kullanılacağını yaz ve aldığın ya da atladığın her dozu not et.',
  ),
  Destination(
    id: DestinationId.nutrition,
    en: 'Nutrition',
    tr: 'Beslenme',
    icon: Icons.restaurant_outlined,
    selectedIcon: Icons.restaurant,
    purposeEn:
        'What you ate or drank, with nutrients only as copied from a label.',
    purposeTr: 'Ne yediğin ya da içtiğin; besin değerleri yalnız etiketten kopyalandığı gibi.',
    // Built in F007 slice 5: entries as typed; no food database, no totals.
    plannedForge: null,
    principleEn: 'A nutrient the label does not report is missing, not zero.',
    principleTr: 'Etikette yazmayan bir besin öğesi eksiktir, sıfır değil.',
    canDoEn: 'Write down a meal or a drink in your own words, with label values if you have them.',
    canDoTr: 'Bir öğünü ya da içeceği kendi sözlerinle yaz; elinde varsa etiket değerleriyle.',
  ),
  Destination(
    id: DestinationId.activity,
    en: 'Activity',
    tr: 'Aktivite',
    icon: Icons.directions_run_outlined,
    selectedIcon: Icons.directions_run,
    purposeEn: 'Walks, workouts and steps typed by hand; sleep is on Today; wearables later.',
    purposeTr: 'Elle yazılan yürüyüş, antrenman ve adımlar; uyku Bugün ekranında; giyilebilir cihazlar ileride.',
    // Built in F007 slice 6 (typed by hand). Device data comes with F013.
    plannedForge: null,
    principleEn:
        'Two devices counting the same hour are de-duplicated, never summed.',
    principleTr: 'Aynı saati sayan iki cihaz tekilleştirilir, asla toplanmaz.',
    canDoEn: 'Add a walk or a workout with its minutes and steps, or leave them empty.',
    canDoTr: 'Bir yürüyüşü ya da antrenmanı dakikası ve adımıyla ekle ya da onları boş bırak.',
  ),
  Destination(
    id: DestinationId.conditions,
    en: 'Conditions',
    tr: 'Durumlar',
    icon: Icons.healing_outlined,
    selectedIcon: Icons.healing,
    purposeEn:
        'Conditions and symptoms in your words, with who they come from.',
    purposeTr:
        'Durumlar ve belirtiler kendi sözlerinle, kimden geldiğiyle birlikte.',
    // Built in F009 slice 1; treatments and care pathways come later.
    plannedForge: null,
    principleEn: 'Self-reported is not a confirmed diagnosis.',
    principleTr: 'Öz bildirim, doğrulanmış tanı değildir.',
    canDoEn: 'Write down a condition or a symptom in your words, and who told you about it.',
    canDoTr: 'Bir durumu ya da belirtiyi kendi sözlerinle yaz; sana kimin söylediğini de ekle.',
  ),
  Destination(
    id: DestinationId.preventive,
    en: 'Preventive',
    tr: 'Koruyucu',
    icon: Icons.shield_outlined,
    selectedIcon: Icons.shield,
    purposeEn: 'Vaccinations, screenings and check-ups in your words: done, planned or not sure. Nothing is recommended or scheduled.',
    purposeTr: 'Aşılar, taramalar ve kontroller kendi sözlerinle: yapıldı, planlandı ya da emin değilim. Hiçbir şey önerilmez ya da takvime konmaz.',
    // Built in F009 slice 2 (as named, no guideline pack, no schedule).
    plannedForge: null,
    principleEn:
        'Unknown history is not "never done". Screening is not diagnosis.',
    principleTr:
        'Bilinmeyen geçmiş "hiç yapılmadı" değildir. Tarama tanı değildir.',
    canDoEn: 'Note a vaccination, a screening or a check-up as done, planned or not sure.',
    canDoTr: 'Bir aşıyı, taramayı ya da kontrolü yapıldı, planlandı ya da emin değilim diye not et.',
  ),
  Destination(
    id: DestinationId.documents,
    en: 'Documents',
    tr: 'Belgeler',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    purposeEn: 'A list of the health documents you keep and where you keep them. Human OS never reads, opens or stores them.',
    purposeTr: 'Sakladığın sağlık belgelerinin ve onları nerede sakladığının listesi. Human OS onları asla okumaz, açmaz ya da saklamaz.',
    // Built in F010 slice 1 (references only; attachments and reviewed
    // extraction come later).
    plannedForge: null,
    principleEn: 'A reference is not the document; Human OS does not read it.',
    principleTr: 'Kayıt belgenin kendisi değildir; Human OS onu okumaz.',
    canDoEn: 'List a document you keep, such as a report or a vaccination card, and where you keep it.',
    canDoTr: 'Sakladığın bir belgeyi (bir rapor ya da aşı kartı gibi) ve nerede durduğunu listele.',
  ),
  Destination(
    id: DestinationId.learn,
    en: 'Learn',
    tr: 'Öğren',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    purposeEn: 'Plain explanations of the words in your records and of the body, and how to do things in Human OS.',
    purposeTr: 'Kayıtlarındaki sözcüklerin ve bedenin sade açıklamaları; uygulamada işlerin nasıl yapıldığı.',
    // U034: hosts the glossary, the body guide and the how-to. The shared
    // lesson pack moves to JSON with F021 (ROADMAP); what this area says it
    // does is built.
    plannedForge: null,
    principleEn: 'An explanation is not a diagnosis or medical advice. Human OS never diagnoses and never tells you what to do about your health.',
    principleTr: 'Bir açıklama tanı ya da tıbbi tavsiye değildir. Human OS asla tanı koymaz, sağlığın için ne yapman gerektiğini söylemez.',
    canDoEn: 'Look up a word, find which specialist looks after which part of the body, or read how to do things in the app.',
    canDoTr: 'Bir sözcüğe bak, bedenin hangi bölümüyle hangi uzmanın ilgilendiğini bul ya da uygulamada işlerin nasıl yapıldığını oku.',
  ),
];

Destination destinationById(DestinationId id) =>
    destinations.firstWhere((d) => d.id == id);

/// Destinations outside primary navigation, in their canonical order.
final List<Destination> plannedDestinations = [
  for (final d in destinations)
    if (!d.isPrimary) d,
];
