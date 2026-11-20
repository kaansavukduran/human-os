/// Plain explanations of the measurements and terms Human OS uses (U003):
/// what each one is, its unit, and how it is usually taken at home. Written
/// for Human OS; measuring steps follow published home-measurement
/// guidance (sources below). No entry gives a target, a range to aim for or
/// a judgement of a value.
library;

import 'body_guide.dart' show Bilingual;

class GlossaryEntry {
  const GlossaryEntry({
    required this.id,
    required this.term,
    required this.what,
    this.unit,
    this.howToMeasure = const [],
    this.kind,
    this.source,
  });

  final String id;
  final Bilingual term;
  final Bilingual what;
  final Bilingual? unit;

  /// Steps for measuring at home, in order.
  final List<Bilingual> howToMeasure;

  /// The Human OS record kind code this entry explains, if any.
  final String? kind;
  final Bilingual? source;
}

const _bpSource = (
  'Home measurement steps after the European Society of Hypertension practice guidance (2021) and WHO HEARTS technical package.',
  'Evde ölçüm adımları Avrupa Hipertansiyon Derneği uygulama rehberine (2021) ve DSÖ HEARTS teknik paketine dayanır.',
);

const List<GlossaryEntry> glossary = [
  GlossaryEntry(
    id: 'blood_pressure',
    kind: 'vital.blood_pressure',
    term: ('Blood pressure', 'Tansiyon (kan basıncı)'),
    what: (
      'The pressure of blood on the artery walls, written as two numbers: systolic (while the heart beats) over diastolic (between beats).',
      'Kanın atardamar duvarlarına yaptığı basınç; iki sayıyla yazılır: sistolik (kalp atarken) / diyastolik (atımlar arasında).',
    ),
    unit: ('mmHg (millimetres of mercury)', 'mmHg (milimetre cıva)'),
    howToMeasure: [
      (
        'Sit quietly for 5 minutes, back supported, feet flat, legs uncrossed.',
        '5 dakika sessizce otur; sırtın destekli, ayakların yerde, bacakların çapraz değil.',
      ),
      (
        'Use a cuff that fits your upper arm, resting at heart level on a table.',
        'Üst koluna uyan bir manşet kullan; kolun masada, kalp hizasında dursun.',
      ),
      (
        'Do not talk during the reading; no coffee, smoking or exercise in the 30 minutes before.',
        'Ölçüm sırasında konuşma; öncesindeki 30 dakikada kahve, sigara ve egzersiz olmasın.',
      ),
      (
        'Take two readings one minute apart and record each as shown.',
        'Bir dakika arayla iki ölçüm al ve her birini ekranda göründüğü gibi kaydet.',
      ),
    ],
    source: _bpSource,
  ),
  GlossaryEntry(
    id: 'heart_rate',
    kind: 'vital.resting_heart_rate',
    term: ('Resting heart rate', 'Dinlenme nabzı'),
    what: (
      'How many times the heart beats in a minute while you are at rest.',
      'Dinlenirken kalbinin bir dakikada kaç kez attığı.',
    ),
    unit: ('beats per minute (bpm)', 'dakikadaki atım (atım/dk)'),
    howToMeasure: [
      (
        'Rest sitting or lying for a few minutes first.',
        'Önce birkaç dakika oturarak ya da uzanarak dinlen.',
      ),
      (
        'Use a device, or count the pulse at the wrist for 60 seconds.',
        'Bir cihaz kullan ya da bilekteki nabzı 60 saniye say.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'temperature',
    kind: 'vital.body_temperature',
    term: ('Body temperature', 'Vücut sıcaklığı'),
    what: (
      'How warm the body is. It differs by where it is measured (mouth, ear, armpit, forehead) and by time of day.',
      'Vücudun ne kadar sıcak olduğu. Ölçüldüğü yere (ağız, kulak, koltuk altı, alın) ve günün saatine göre değişir.',
    ),
    unit: ('degrees Celsius (°C)', 'santigrat derece (°C)'),
    howToMeasure: [
      (
        'Use the thermometer as its instructions say, and note where you measured.',
        'Termometreyi talimatına göre kullan ve nereden ölçtüğünü not et.',
      ),
      (
        'Wait 15 minutes after a hot or cold drink before a mouth reading.',
        'Ağızdan ölçmeden önce sıcak ya da soğuk bir içecekten sonra 15 dakika bekle.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'spo2',
    kind: 'vital.oxygen_saturation',
    term: ('Oxygen saturation (SpO2)', 'Oksijen satürasyonu (SpO2)'),
    what: (
      'The share of the blood\'s oxygen carriers that carry oxygen, read by a clip on a finger (pulse oximeter).',
      'Kandaki oksijen taşıyıcılarının oksijen taşıyan payı; parmağa takılan bir mandalla (nabız oksimetresi) okunur.',
    ),
    unit: ('percent (%)', 'yüzde (%)'),
    howToMeasure: [
      (
        'Sit still with a warm hand resting at heart level.',
        'Elin sıcak ve kalp hizasında dururken kıpırdamadan otur.',
      ),
      (
        'Remove nail polish or false nails on that finger; wait until the number stops changing.',
        'O parmaktaki ojeyi ya da takma tırnağı çıkar; sayı değişmeyi bırakana kadar bekle.',
      ),
      (
        'Readings can differ by skin tone and device; note the device you use.',
        'Okumalar ten rengine ve cihaza göre farklılık gösterebilir; kullandığın cihazı not et.',
      ),
    ],
    source: (
      'Pulse oximeter accuracy notes after the US FDA safety communication on pulse oximeters (2021, updated 2024).',
      'Nabız oksimetresi doğruluğu notları ABD FDA\'nın nabız oksimetreleri hakkındaki güvenlik bildirimine (2021, 2024 güncellemesi) dayanır.',
    ),
  ),
  GlossaryEntry(
    id: 'respiratory_rate',
    kind: 'vital.respiratory_rate',
    term: ('Respiratory rate', 'Solunum hızı'),
    what: (
      'How many breaths you take in a minute at rest.',
      'Dinlenirken bir dakikada kaç kez nefes aldığın.',
    ),
    unit: ('breaths per minute', 'dakikadaki soluk'),
    howToMeasure: [
      (
        'Rest first; count each rise of the chest for 60 seconds.',
        'Önce dinlen; göğsünün her yükselişini 60 saniye say.',
      ),
      (
        'It is easier if someone else counts, because knowing you are counted changes breathing.',
        'Başka biri sayarsa daha kolaydır, çünkü sayıldığını bilmek nefesi değiştirir.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'weight',
    kind: 'body.weight',
    term: ('Body weight', 'Vücut ağırlığı'),
    what: (
      'How heavy the body is. It changes during the day with food, drink and the bathroom.',
      'Vücudun ne kadar ağır olduğu. Gün içinde yemek, içmek ve tuvaletle değişir.',
    ),
    unit: ('kilograms (kg)', 'kilogram (kg)'),
    howToMeasure: [
      (
        'Use the same scale on a hard, flat floor.',
        'Sert ve düz bir zeminde hep aynı tartıyı kullan.',
      ),
      (
        'Weigh at a similar time of day in similar clothes, so readings compare.',
        'Ölçümler karşılaştırılabilsin diye günün benzer saatinde, benzer kıyafetle tartıl.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'height',
    kind: 'body.height',
    term: ('Height', 'Boy'),
    what: (
      'How tall you are standing, without shoes.',
      'Ayakkabısız ayakta dururken ne kadar uzun olduğun.',
    ),
    unit: ('centimetres (cm)', 'santimetre (cm)'),
    howToMeasure: [
      (
        'Stand with heels, back and head against a wall, looking straight ahead.',
        'Topukların, sırtın ve başın duvara değerek dik dur, karşıya bak.',
      ),
      (
        'Mark the top of the head with a flat object and measure from the floor.',
        'Başının üstünü düz bir nesneyle işaretle ve yerden ölç.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'waist',
    kind: 'body.waist_circumference',
    term: ('Waist circumference', 'Bel çevresi'),
    what: (
      'The distance around the waist. Where it is measured changes the number, so keep to one place.',
      'Belin çevresinin uzunluğu. Ölçülen yer sayıyı değiştirir, bu yüzden hep aynı yerden ölç.',
    ),
    unit: ('centimetres (cm)', 'santimetre (cm)'),
    howToMeasure: [
      (
        'Stand relaxed and breathe out gently.',
        'Rahat dur ve nefesini yavaşça ver.',
      ),
      (
        'Put the tape midway between the lowest rib and the top of the hip bone, level all around, not pressing the skin.',
        'Mezurayı en alt kaburga ile kalça kemiğinin üstü arasının ortasına, her yerde aynı seviyede ve deriyi sıkmadan yerleştir.',
      ),
    ],
    source: (
      'Measuring site after the WHO Expert Consultation on waist circumference (2008).',
      'Ölçüm yeri DSÖ bel çevresi uzman danışma raporuna (2008) dayanır.',
    ),
  ),
  GlossaryEntry(
    id: 'capillary_glucose',
    kind: 'glucose.capillary',
    term: (
      'Blood glucose (finger-prick meter)',
      'Kan şekeri (parmaktan ölçüm)',
    ),
    what: (
      'The amount of sugar (glucose) in a drop of blood from the fingertip, as a home meter shows it. A laboratory glucose from a vein is a different measurement and goes in Labs.',
      'Parmak ucundan alınan bir damla kandaki şeker (glukoz) miktarı; evdeki ölçüm cihazının gösterdiği gibi. Damardan alınan laboratuvar glukozu başka bir ölçümdür ve Tahliller\'e girilir.',
    ),
    unit: (
      'mg/dL or mmol/L, whichever your meter shows; Human OS keeps the one you choose and never converts',
      'mg/dL ya da mmol/L, cihazın hangisini gösteriyorsa; Human OS seçtiğini saklar ve asla çevirmez',
    ),
    howToMeasure: [
      (
        'Wash and dry your hands; follow the instructions of your meter and strips.',
        'Ellerini yıka ve kurula; cihazının ve şeritlerinin talimatına uy.',
      ),
      (
        'Write down the number and the unit exactly as the meter shows them, and whether you had eaten.',
        'Sayıyı ve birimi cihazın gösterdiği gibi yaz; yemek yiyip yemediğini de belirt.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'body_fat',
    kind: 'body.fat_percentage',
    term: ('Body fat (device estimate)', 'Vücut yağı (cihaz tahmini)'),
    what: (
      'The share of body weight a scale or other device estimates to be fat. The device calculates it from a small electric current and its own formula, so it is an estimate, and devices differ.',
      'Bir tartının ya da başka bir cihazın vücut ağırlığının yağ olduğunu tahmin ettiği pay. Cihaz bunu zayıf bir elektrik akımı ve kendi formülüyle hesaplar; bu yüzden bir tahmindir ve cihazlar farklı sonuç verir.',
    ),
    unit: ('percent (%)', 'yüzde (%)'),
    howToMeasure: [
      (
        'Use the same device at the same time of day, barefoot, as its instructions say.',
        'Aynı cihazı günün aynı saatinde, çıplak ayakla ve talimatına göre kullan.',
      ),
      (
        'Write down the number the device shows; it is not a measurement of the fat itself.',
        'Cihazın gösterdiği sayıyı yaz; bu yağın kendisinin ölçümü değildir.',
      ),
    ],
  ),
  GlossaryEntry(
    id: 'reference_interval',
    term: ('Reference interval', 'Referans aralığı'),
    what: (
      'The range a laboratory prints beside a result: where most results of a chosen group of people fall. It describes that group, not a value to reach, and a result outside it is not by itself a finding.',
      'Laboratuvarın sonucun yanına yazdığı aralık: seçilmiş bir grubun sonuçlarının çoğunun düştüğü yer. O grubu anlatır, ulaşılacak bir değer değildir; dışında kalan bir sonuç tek başına bir bulgu değildir.',
    ),
  ),
  GlossaryEntry(
    id: 'flag',
    term: ('Lab flag (H, L)', 'Laboratuvar işareti (H, L)'),
    what: (
      'A letter the laboratory adds when a result is above (H) or below (L) its printed interval. Human OS shows it as the lab\'s, not its own.',
      'Laboratuvarın, sonuç yazdığı aralığın üstünde (H) ya da altında (L) olduğunda eklediği harf. Human OS bunu laboratuvarınki olarak gösterir, kendi yorumu olarak değil.',
    ),
  ),
  GlossaryEntry(
    id: 'unit',
    term: ('Unit', 'Birim'),
    what: (
      'What a number counts (mg/dL, mmol/L, kg). The same test can be printed in different units by different labs; Human OS keeps the unit as printed.',
      'Bir sayının neyi saydığı (mg/dL, mmol/L, kg). Aynı test farklı laboratuvarlarca farklı birimle yazılabilir; Human OS birimi yazıldığı gibi saklar.',
    ),
  ),
  GlossaryEntry(
    id: 'correction',
    term: ('Correction', 'Düzeltme'),
    what: (
      'A new version of a value you entered. The old one stays in the history; nothing is overwritten.',
      'Girdiğin bir değerin yeni sürümü. Eskisi geçmişte kalır; hiçbir şeyin üzerine yazılmaz.',
    ),
  ),
  GlossaryEntry(
    id: 'snp',
    term: ('Variant (SNP) and genotype', 'Varyant (SNP) ve genotip'),
    what: (
      'A variant is a place in the DNA where people differ; an rsID names it. A genotype is the pair of letters your file lists there. A listed variant says nothing on its own about health.',
      'Varyant, DNA\'da insanların farklılaştığı bir yerdir; rsID onu adlandırır. Genotip, dosyanın orada listelediği harf çiftidir. Listelenen bir varyant sağlık hakkında tek başına bir şey söylemez.',
    ),
  ),
];

const Bilingual glossaryAuthorship = (
  'Explanations written for Human OS in plain words. They do not give targets and do not replace a clinician.',
  'Açıklamalar Human OS için sade bir dille yazıldı. Hedef vermez ve hekimin yerini tutmaz.',
);

GlossaryEntry? glossaryForKind(String code) {
  for (final e in glossary) {
    if (e.kind == code) return e;
  }
  return null;
}

/// The entry with [id], or null when the glossary has none (U031: a term
/// link is shown only for a word the glossary explains).
GlossaryEntry? glossaryById(String id) {
  for (final e in glossary) {
    if (e.id == id) return e;
  }
  return null;
}
