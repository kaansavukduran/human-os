# DECISIONS: what was decided, why, and what was rejected?
Kabul ve ret kararları, tarihli, yalnız eklenir. Tam metin: [project_state/DECISIONS.md](../project_state/DECISIONS.md) (validator ve geçmiş ona bağlı).
Kurallar: silme, SUPERSEDED işaretle; giriş ≤ 5 satır; sahip kararında "Sahip: Kaan". Yeni giriş bu dosyanın sonuna eklenir.
Eski kayıtlar: [01 ADR-IMPL-002, D-003…D-013](decisions/01_ADR-IMPL-002_D-013.md) · [02 D-014…D-027](decisions/02_D-014_D-027.md) · [03 D-028…D-040](decisions/03_D-028_D-040.md).
Kaynakta D-001, D-002 ve ADR-IMPL-001 girişi yok; D-029 iki kez kullanılmış (D-029a/b).

## D-041 · 2026-11-12 · KABUL
Karar: Linux paketleri motorun dlopen ettiği GL kütüphanelerini bildirir (deb: libgles2, libgl1; rpm: libGLESv2.so.2, libGL.so.1) (F015-L2).
Neden: dlopen bağımlılıkları ldd ve shlibdeps'te görünmez; minimal Ubuntu 22.04/24.04'te açılışta çöküş (R-15).
Reddedilen: GL kütüphanelerini paketle göndermek (sistem sürücüleriyle eşleşmeli).
Kısıt/Etki: Düzeltilmiş deb minimal chroot'ta RUNTIME_TESTED; rpm, Wayland, Debian/Fedora/Nobara NOT_RUN.

## D-042 · 2026-11-19 · KABUL
Karar: Lexend isteğe bağlı okuma yazı tipi, paketle (SIL OFL 1.1, statik 400/600) (U031-S2).
Neden: Sahibin isteği (kendi başka uygulamasındaki yazı tipi).
Reddedilen: google_fonts paketi (çalışma anında indirir).
Kısıt/Etki: Varsayılan cihaz fontu; kanıtlı yardım değil, beğeni seçeneği; eski sürüm cihaz fontu okur (R-20).
Sahip: Kaan

## D-043 · 2026-11-19 · KABUL
Karar: Sınır altı/üstü ("< 5") ve metin ("Pozitif") lab sonuçları basıldığı gibi; sayı olarak okunmaz (RS-014, F004-S2).
Neden: "< 5" 5 değildir; metin olumlu/olumsuz anlamına eşlenmez.
Reddedilen: Sınırı sayı saymak; metni yorumlamak.
Kısıt/Etki: Hesaplar lab değerini yalnız `labNumberFor` ile okur; şema 13 uygulaması şema 14 deposunu reddeder.

## D-044 · 2026-11-19 · KABUL
Karar: Şifreli kasadan dışa aktarma yalnız "şifresiz dosya" uyarısı ve onayla, sistem kaydet penceresine; tarayıcıda seçilen yedek aynı aşamalı kapıdan geri yüklenir (F005-S2).
Neden: G-34 ve G-29.
Reddedilen: Dışa aktarmayı kasanın yanına veya istenmeden yazmak; şifreli yedeği tarayıcıda açmak (dart2js'te kripto yok).
Kısıt/Etki: Tarayıcıda 64 MiB, dev web'de 4 MiB sınırı; Windows/macOS kaydet penceresi NOT_RUN.

## D-045 · 2026-11-19 · KABUL
Karar: Rapor zamanı, yöntem ve referans aralığı basıldığı gibi, sonuçtan ayrı (RS-015, F004-S3).
Neden: referans aralığı ≠ hedef ≠ klinik karar sınırı.
Reddedilen: Sonucu aralıkla karşılaştırmak, bayrak veya renk hesaplamak; aralığı basılı metinden türetmek.
Kısıt/Etki: Tek sayısal okuma alt/üst sıra denetimi; yaş/cinsiyet uygulanabilirliği G-27'ye kalır.

## D-046 · 2026-11-19 · KABUL
Karar: Kurtarma anahtarı iki rastgele grubu yazarak onaylanır; isteğe bağlı uygulama kilidi anahtarı düşürür, kayıtlar kalır (F006-S2).
Neden: G-38 ve G-36.
Reddedilen: Yalnız onay kutusu; deneme sınırı veya kilitlenme.
Kısıt/Etki: Kilit hiçbir şey yazmaz; bellekteki metin silinemez (G-37); biyometri yok (G-13).

## D-047 · 2026-11-20 · KABUL
Karar: Ölçüm düzeltmesi okumayı gerçek zamanına taşıyabilir; rutin hayati bulgular için "Bunu ölçmedim" (F007-S7).
Neden: G-48; kaçan rutin okuma da bilgidir.
Reddedilen: Bel ve boyda "ölçmedim" (ara sıra ölçülür); hiçbir şey değiştirmeyen düzeltme (`NO_CHANGE`).
Kısıt/Etki: Yeni şema yok; "ölçülmedi" asla sayı veya sıfır değildir.
Yerini aldığı: D-019 (düzeltme zamanı kuralı)

## D-048 · 2026-11-20 · KABUL
Karar: Kılcal kan şekeri cihazın birimiyle (mg/dL veya mmol/L, dönüşümsüz); vücut yağı cihazın tahmini, durum `reported` (RS-016, F007-S8).
Neden: aynı görünen ad ≠ aynı ölçüm; model çıktısı ≠ gözlenen olgu.
Reddedilen: Birim dönüştürmek veya sayıdan tahmin etmek; kas kütlesi, visseral yağ (v0.24 tanımlamıyor).
Kısıt/Etki: Öğün zamanı yalnız seçilirse; aralık, renk veya diyabet kelimesi yok.

## D-049 · 2026-11-20 · KABUL
Karar: Her development indirmesinin yanında `-encrypted-` adlı şifreli (staging) indirme; web yalnız development (D002).
Neden: Gerçek kayıt tutmak isteyenin güvenli dosyası yoktu.
Reddedilen: Development dosyalarına "unencrypted" adı (göz karıştırır), "trial" (süre sınırı çağrıştırır); şifreli web zip (kalıcı tutamaz, G-32).
Kısıt/Etki: Yan yana kurulur (Android hariç); başlatma denetimi yalnız "yazmadan başlar"ı kanıtlar.

## D-050 · 2026-11-21 · KABUL
Karar: Development kayıtları yalnız boş şifreli kasaya, aşamalı geri yükleme kapısından, şifresiz-dosya uyarısıyla girer (F005-S3).
Neden: Dolu kasaya birleştirme kayıtları gizleyebilir veya sırasını bozabilir.
Reddedilen: Birleştirme (G-76 açık); ters yön (şifreliden development'a).
Kısıt/Etki: Kaynak dosya silinmez; önceki zarf `.before-restore-<time>` olarak kalır.

## D-051 · 2026-11-24 · KABUL
Karar: Kurgusal lore `docs/lore/` içinde; ürün sınırı değişmez, lore tıbbi içeriğe girmez.
Neden: Sahibin isteği ("github içerisinde lore yapısı oluştur").
Reddedilen: İkinci bir `LORE_LINKS.md` dosyası.
Kısıt/Etki: İstek sonradan proje sürekliliği (bu `LORE/`) olarak anlaşıldı; sahip 2026-11-25'te `docs/lore`'un kalmasına karar verdi.
Sahip: Kaan

## D-052 · 2026-11-25 · KABUL
Karar: Proje hafızası `LORE/`; CLAUDE.md ve AGENTS.md ≤25 satırlık yönlendirici; ayrıntı LORE dosyalarında, tam karar metni project_state/DECISIONS.md'de.
Neden: Yeni oturum projeyi baştan taramadan devam etsin; her turda yüklenen metin kısa kalsın.
Reddedilen: Uzun CLAUDE.md'yi korumak (her turda tekrar okunur); project_state/'i silmek (doğrulayıcılar ona bağlı).
Kısıt/Etki: Özel Drive yedek klasörü kimliği repoda tutulmaz. Sahip: Kaan

## D-053 · 2026-11-25 · KABUL
Karar: Development kayıtları dolu şifreli kasaya kimlikle birleşir: aynı kimlik + aynı bayt atlanır, aynı kimlik + farklı bayt bütün aktarımı durdurur, yeni kimlikler kasanın değişmeyen satırlarının arkasına eklenir (F005-S4).
Neden: G-76; hiçbir kayıt yeniden yazılmaz, sıra zaman çizelgesi kurallarından gelir, önizleme yeni/atlanan/engelleyen sayar.
Reddedilen: Kayıtları kasanın SELF profiline yeniden bağlamak (profile_id kaydın baytıdır); profil eşlemesi (her ekran, düzeltme kuralı ve dışa aktarım profile göre); dosyada hedefi olmayan düzeltme.
Kısıt/Etki: Yalnız aynı SELF profili; okunamayan girdili veya salt okunur kasa reddedilir; önizlemeden sonra değişen kasa yazılmaz (`IMPORT_VAULT_CHANGED`); önceki zarf saklanır, adı alınmışsa bir saniye ileri (ad özel oluşturmayla alınır). R026: aynı kaydın her iki sürümdeki iki farklı düzeltmesi de engelleyen çakışmadır (`IMPORT_CORRECTIONS_COMPETE`); geçiş öncesi oturum kilitlenir ve süren yazmalar beklenir, kasa yeniden okunur, değiştiyse geçilmez (`RESTORE_NOT_SWITCHED`/`VAULT_CHANGED`); geri yüklemede de aynı yol.
